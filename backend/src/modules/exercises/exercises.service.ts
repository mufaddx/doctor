import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { UploadsService } from '../uploads/uploads.service';
import {
  buildOrderBy,
  buildPagination,
  paginate,
} from '../../common/utils/pagination.util';
import {
  AssignExercisesDto,
  CreateExerciseDto,
  ListExercisesDto,
  UpdateExerciseDto,
} from './dto/exercise.dto';

const SORTABLE_FIELDS = ['title', 'durationMinutes', 'createdAt'];

@Injectable()
export class ExercisesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly uploads: UploadsService,
    private readonly notifications: NotificationsService,
  ) {}

  // -------------------------------------------------------
  // LIBRARY
  // -------------------------------------------------------

  /**
   * Browsable exercise library. Patients and therapists see global exercises
   * plus anything the requesting therapist authored themselves.
   */
  async findAll(dto: ListExercisesDto, therapistId?: string) {
    const { skip, take, page, limit } = buildPagination(dto);

    const where: Prisma.ExerciseWhereInput = {
      ...(therapistId
        ? { OR: [{ isGlobal: true }, { therapistId }] }
        : { isGlobal: true }),
      ...(dto.category ? { category: dto.category } : {}),
      ...(dto.level ? { level: dto.level } : {}),
      ...(dto.search
        ? { title: { contains: dto.search, mode: 'insensitive' } }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.exercise.findMany({
        where,
        skip,
        take,
        orderBy: buildOrderBy(dto, SORTABLE_FIELDS, 'createdAt'),
      }),
      this.prisma.exercise.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  /** Distinct categories used to build the filter chips in the apps. */
  async getCategories() {
    const rows = await this.prisma.exercise.findMany({
      where: { isGlobal: true },
      select: { category: true },
      distinct: ['category'],
      orderBy: { category: 'asc' },
    });
    return rows.map((r) => r.category);
  }

  async findOne(id: string) {
    const exercise = await this.prisma.exercise.findUnique({ where: { id } });
    if (!exercise) throw new NotFoundException('Exercise not found');
    return exercise;
  }

  /** Therapists create private exercises; admins publish global ones. */
  async create(dto: CreateExerciseDto, therapistUserId?: string) {
    let therapistId: string | undefined;

    if (therapistUserId) {
      const therapist = await this.prisma.therapist.findUnique({
        where: { userId: therapistUserId },
        select: { id: true },
      });
      if (!therapist) throw new NotFoundException('Therapist profile not found');
      therapistId = therapist.id;
    }

    return this.prisma.exercise.create({
      data: {
        therapistId,
        title: dto.title,
        category: dto.category,
        level: dto.level,
        durationMinutes: dto.durationMinutes,
        videoUrl: dto.videoUrl,
        thumbnailUrl: dto.thumbnailUrl,
        instructions: dto.instructions ?? [],
        // Only admin-created exercises enter the shared library
        isGlobal: !therapistUserId,
      },
    });
  }

  async update(id: string, dto: UpdateExerciseDto) {
    return this.prisma.exercise.update({
      where: { id },
      data: {
        title: dto.title,
        category: dto.category,
        level: dto.level,
        durationMinutes: dto.durationMinutes,
        videoUrl: dto.videoUrl,
        thumbnailUrl: dto.thumbnailUrl,
        instructions: dto.instructions,
      },
    });
  }

  async remove(id: string) {
    const assigned = await this.prisma.exerciseAssignment.count({
      where: { exerciseId: id },
    });
    if (assigned > 0) {
      throw new BadRequestException(
        'This exercise is assigned to patients and cannot be deleted',
      );
    }

    const exercise = await this.prisma.exercise.findUnique({ where: { id } });
    if (!exercise) throw new NotFoundException('Exercise not found');

    await this.uploads.deleteByUrl(exercise.videoUrl);
    if (exercise.thumbnailUrl) await this.uploads.deleteByUrl(exercise.thumbnailUrl);

    await this.prisma.exercise.delete({ where: { id } });
    return { message: 'Exercise deleted' };
  }

  async uploadVideo(file: Express.Multer.File) {
    const url = await this.uploads.uploadVideo(file, 'exercises/videos');
    return { videoUrl: url };
  }

  async uploadThumbnail(file: Express.Multer.File) {
    const url = await this.uploads.uploadImage(file, 'exercises/thumbnails');
    return { thumbnailUrl: url };
  }

  // -------------------------------------------------------
  // ASSIGNMENT
  // -------------------------------------------------------

  /**
   * Assigns a set of exercises to a patient. Assignments hang off a progress
   * log entry so the plan is anchored to a point in the patient's timeline.
   */
  async assignToPatient(therapistUserId: string, dto: AssignExercisesDto) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
      select: { id: true, user: { select: { fullName: true } } },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    // A therapist may only prescribe exercises to patients they have treated
    const treated = await this.prisma.appointment.count({
      where: { therapistId: therapist.id, patientId: dto.patientId },
    });
    if (treated === 0) throw new NotFoundException('Patient not found in your records');

    const patient = await this.prisma.patient.findUnique({
      where: { id: dto.patientId },
      select: { userId: true },
    });
    if (!patient) throw new NotFoundException('Patient not found');

    const exerciseIds = dto.exercises.map((e) => e.exerciseId);
    const found = await this.prisma.exercise.count({ where: { id: { in: exerciseIds } } });
    if (found !== exerciseIds.length) {
      throw new BadRequestException('One or more exercises do not exist');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const log = await tx.progressLog.create({
        data: {
          patientId: dto.patientId,
          condition: dto.condition,
          painLevel: dto.painLevel ?? 0,
          notes: dto.notes,
        },
      });

      await tx.exerciseAssignment.createMany({
        data: dto.exercises.map((e) => ({
          exerciseId: e.exerciseId,
          progressLogId: log.id,
          sets: e.sets ?? 3,
        })),
      });

      return tx.progressLog.findUniqueOrThrow({
        where: { id: log.id },
        include: { assignments: { include: { exercise: true } } },
      });
    });

    await this.notifications.send({
      userId: patient.userId,
      type: NotificationType.SYSTEM,
      title: 'New exercise plan',
      body: `${therapist.user.fullName} assigned you ${dto.exercises.length} exercises.`,
      data: { progressLogId: result.id },
    });

    return result;
  }

  /** The patient's current plan: every assigned exercise with its status. */
  async getMyPlan(patientUserId: string) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    const logs = await this.prisma.progressLog.findMany({
      where: { patientId: patient.id, assignments: { some: {} } },
      orderBy: { loggedAt: 'desc' },
      include: { assignments: { include: { exercise: true } } },
    });

    const assignments = logs.flatMap((log) =>
      log.assignments.map((a) => ({
        assignmentId: a.id,
        sets: a.sets,
        completed: a.completed,
        completedAt: a.completedAt,
        assignedAt: a.assignedAt,
        condition: log.condition,
        exercise: a.exercise,
      })),
    );

    const completed = assignments.filter((a) => a.completed).length;

    return {
      assignments,
      summary: {
        total: assignments.length,
        completed,
        pending: assignments.length - completed,
        sessionsLogged: logs.length,
      },
    };
  }

  /** Patient marks an assigned exercise done (idempotent). */
  async markCompleted(patientUserId: string, assignmentId: string) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    const assignment = await this.prisma.exerciseAssignment.findFirst({
      where: { id: assignmentId, progressLog: { patientId: patient.id } },
    });
    if (!assignment) throw new NotFoundException('Exercise assignment not found');

    if (assignment.completed) return assignment;

    return this.prisma.exerciseAssignment.update({
      where: { id: assignmentId },
      data: { completed: true, completedAt: new Date() },
    });
  }
}
