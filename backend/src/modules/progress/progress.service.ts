import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateProgressLogDto, ProgressChartQueryDto } from './dto/progress.dto';

@Injectable()
export class ProgressService {
  constructor(private readonly prisma: PrismaService) {}

  /** Patient logs how their pain feels today. */
  async log(patientUserId: string, dto: CreateProgressLogDto) {
    const patientId = await this.requirePatientId(patientUserId);

    return this.prisma.progressLog.create({
      data: {
        patientId,
        condition: dto.condition,
        painLevel: dto.painLevel,
        notes: dto.notes,
      },
    });
  }

  /**
   * Time-series data for the pain-level chart, plus a trend summary so the
   * app can show "improving" or "worsening" without recomputing client side.
   */
  async getChart(patientUserId: string, query: ProgressChartQueryDto) {
    const patientId = await this.requirePatientId(patientUserId);
    return this.buildChart(patientId, query);
  }

  /** Same chart, but requested by a therapist for one of their patients. */
  async getChartForTherapist(
    therapistUserId: string,
    patientId: string,
    query: ProgressChartQueryDto,
  ) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const treated = await this.prisma.appointment.count({
      where: { therapistId: therapist.id, patientId },
    });
    if (treated === 0) throw new NotFoundException('Patient not found in your records');

    return this.buildChart(patientId, query);
  }

  /** Conditions the patient has ever logged, for the chart dropdown. */
  async getConditions(patientUserId: string) {
    const patientId = await this.requirePatientId(patientUserId);

    const rows = await this.prisma.progressLog.findMany({
      where: { patientId },
      select: { condition: true },
      distinct: ['condition'],
      orderBy: { condition: 'asc' },
    });

    return rows.map((r) => r.condition);
  }

  private async buildChart(patientId: string, query: ProgressChartQueryDto) {
    const days = query.days ?? 30;
    const since = new Date();
    since.setDate(since.getDate() - days);
    since.setHours(0, 0, 0, 0);

    const logs = await this.prisma.progressLog.findMany({
      where: {
        patientId,
        loggedAt: { gte: since },
        ...(query.condition ? { condition: query.condition } : {}),
      },
      orderBy: { loggedAt: 'asc' },
      select: { id: true, condition: true, painLevel: true, notes: true, loggedAt: true },
    });

    const [assignmentStats, sessionCount] = await this.prisma.$transaction([
      this.prisma.exerciseAssignment.groupBy({
        by: ['completed'],
        where: { progressLog: { patientId } },
        _count: { _all: true },
      }),
      this.prisma.appointment.count({
        where: { patientId, status: 'COMPLETED' },
      }),
    ]);

    const completedExercises =
      assignmentStats.find((s) => s.completed)?._count._all ?? 0;
    const pendingExercises =
      assignmentStats.find((s) => !s.completed)?._count._all ?? 0;

    return {
      points: logs.map((log) => ({
        date: log.loggedAt.toISOString().slice(0, 10),
        painLevel: log.painLevel,
        condition: log.condition,
        notes: log.notes,
      })),
      summary: {
        completedExercises,
        pendingExercises,
        sessionsCompleted: sessionCount,
        ...this.trendFor(logs.map((l) => l.painLevel)),
      },
    };
  }

  /**
   * Compares the average pain of the first and second half of the window.
   * A falling average means the patient is improving.
   */
  private trendFor(painLevels: number[]) {
    if (painLevels.length < 2) {
      return { trend: 'insufficient_data' as const, changePercent: 0, currentPain: painLevels[0] ?? null };
    }

    const midpoint = Math.floor(painLevels.length / 2);
    const average = (values: number[]) =>
      values.reduce((sum, v) => sum + v, 0) / values.length;

    const earlier = average(painLevels.slice(0, midpoint));
    const later = average(painLevels.slice(midpoint));

    const changePercent = earlier === 0 ? 0 : ((later - earlier) / earlier) * 100;

    // A swing under 5% is treated as noise rather than a real trend
    const trend =
      Math.abs(changePercent) < 5 ? 'stable' : changePercent < 0 ? 'improving' : 'worsening';

    return {
      trend,
      changePercent: Math.round(changePercent * 10) / 10,
      currentPain: painLevels[painLevels.length - 1],
    };
  }

  private async requirePatientId(userId: string): Promise<string> {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');
    return patient.id;
  }
}
