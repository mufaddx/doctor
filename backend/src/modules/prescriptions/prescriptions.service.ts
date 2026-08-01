import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AppointmentStatus, NotificationType, Prisma, UserRole } from '@prisma/client';
import * as PDFDocument from 'pdfkit';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { UploadsService } from '../uploads/uploads.service';
import { buildPagination, paginate, PaginationQueryDto } from '../../common/utils/pagination.util';
import { CreatePrescriptionDto, UpdatePrescriptionDto } from './dto/prescription.dto';

@Injectable()
export class PrescriptionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly uploads: UploadsService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * A therapist writes the prescription against a specific appointment.
   * The PDF is rendered immediately so the patient can download it offline.
   */
  async create(therapistUserId: string, dto: CreatePrescriptionDto) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
      select: { id: true, user: { select: { fullName: true } } },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: dto.appointmentId, therapistId: therapist.id },
      include: {
        prescription: { select: { id: true } },
        patient: {
          select: {
            id: true,
            userId: true,
            dateOfBirth: true,
            gender: true,
            user: { select: { fullName: true } },
          },
        },
      },
    });

    if (!appointment) throw new NotFoundException('Appointment not found in your records');
    if (appointment.prescription) {
      throw new BadRequestException('A prescription already exists for this appointment');
    }

    const notCompletable: AppointmentStatus[] = [
      AppointmentStatus.CANCELLED,
      AppointmentStatus.REJECTED,
      AppointmentStatus.PENDING,
    ];
    if (notCompletable.includes(appointment.status)) {
      throw new BadRequestException(
        'A prescription can only be issued for a confirmed or completed appointment',
      );
    }

    const prescription = await this.prisma.prescription.create({
      data: {
        appointmentId: appointment.id,
        patientId: appointment.patient.id,
        therapistId: therapist.id,
        diagnosis: dto.diagnosis,
        advice: dto.advice,
        medicines: dto.medicines as unknown as Prisma.InputJsonValue,
      },
    });

    // Render and attach the PDF; a rendering failure must not lose the record
    const pdfUrl = await this.renderPdf({
      prescriptionId: prescription.id,
      patientName: appointment.patient.user.fullName,
      patientAge: appointment.patient.dateOfBirth
        ? this.ageFrom(appointment.patient.dateOfBirth)
        : null,
      patientGender: appointment.patient.gender,
      therapistName: therapist.user.fullName,
      diagnosis: dto.diagnosis,
      advice: dto.advice,
      medicines: dto.medicines,
      issuedAt: prescription.createdAt,
    }).catch(() => null);

    const saved = pdfUrl
      ? await this.prisma.prescription.update({
          where: { id: prescription.id },
          data: { pdfUrl },
        })
      : prescription;

    await this.notifications.send({
      userId: appointment.patient.userId,
      type: NotificationType.SYSTEM,
      title: 'Prescription ready',
      body: `${therapist.user.fullName} has issued your prescription.`,
      data: { prescriptionId: saved.id, appointmentId: appointment.id },
    });

    return saved;
  }

  async update(therapistUserId: string, prescriptionId: string, dto: UpdatePrescriptionDto) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
      select: { id: true, user: { select: { fullName: true } } },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const existing = await this.prisma.prescription.findFirst({
      where: { id: prescriptionId, therapistId: therapist.id },
      include: {
        patient: {
          select: { dateOfBirth: true, gender: true, user: { select: { fullName: true } } },
        },
      },
    });
    if (!existing) throw new NotFoundException('Prescription not found');

    const medicines = (dto.medicines ?? existing.medicines) as any;

    const updated = await this.prisma.prescription.update({
      where: { id: prescriptionId },
      data: {
        diagnosis: dto.diagnosis ?? existing.diagnosis,
        advice: dto.advice ?? existing.advice,
        medicines: medicines as Prisma.InputJsonValue,
      },
    });

    // The old PDF no longer matches the record, so replace it
    if (existing.pdfUrl) await this.uploads.deleteByUrl(existing.pdfUrl);

    const pdfUrl = await this.renderPdf({
      prescriptionId: updated.id,
      patientName: existing.patient.user.fullName,
      patientAge: existing.patient.dateOfBirth ? this.ageFrom(existing.patient.dateOfBirth) : null,
      patientGender: existing.patient.gender,
      therapistName: therapist.user.fullName,
      diagnosis: updated.diagnosis,
      advice: updated.advice,
      medicines,
      issuedAt: updated.createdAt,
    }).catch(() => null);

    return pdfUrl
      ? this.prisma.prescription.update({ where: { id: updated.id }, data: { pdfUrl } })
      : updated;
  }

  async findAllForUser(userId: string, role: UserRole, query: PaginationQueryDto) {
    const { skip, take, page, limit } = buildPagination(query);

    const where = await this.scopeFor(userId, role);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.prescription.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: {
          therapist: {
            select: { id: true, user: { select: { fullName: true, avatarUrl: true } } },
          },
          patient: { select: { id: true, user: { select: { fullName: true } } } },
          appointment: { select: { id: true, scheduledDate: true, type: true } },
        },
      }),
      this.prisma.prescription.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  async findOne(userId: string, role: UserRole, prescriptionId: string) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
      include: {
        therapist: {
          select: {
            userId: true,
            specialization: true,
            user: { select: { fullName: true, avatarUrl: true } },
          },
        },
        patient: {
          select: {
            userId: true,
            gender: true,
            dateOfBirth: true,
            user: { select: { fullName: true } },
          },
        },
        appointment: { select: { id: true, scheduledDate: true, startTime: true, type: true } },
      },
    });

    if (!prescription) throw new NotFoundException('Prescription not found');

    const allowed =
      role === UserRole.ADMIN ||
      role === UserRole.SUPER_ADMIN ||
      prescription.patient.userId === userId ||
      prescription.therapist.userId === userId;

    if (!allowed) throw new ForbiddenException('You cannot view this prescription');

    return prescription;
  }

  // -------------------------------------------------------
  // PDF RENDERING
  // -------------------------------------------------------

  /**
   * Builds an A4 prescription document in memory and uploads it to storage.
   * Streaming into a buffer avoids writing temp files on the server.
   */
  private async renderPdf(data: {
    prescriptionId: string;
    patientName: string;
    patientAge: number | null;
    patientGender: string | null;
    therapistName: string;
    diagnosis: string;
    advice?: string | null;
    medicines: { name: string; dosage: string; frequency?: string }[];
    issuedAt: Date;
  }): Promise<string> {
    const buffer = await new Promise<Buffer>((resolve, reject) => {
      const doc = new PDFDocument({ size: 'A4', margin: 50 });
      const chunks: Buffer[] = [];

      doc.on('data', (chunk) => chunks.push(chunk as Buffer));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      // Header
      doc.fontSize(20).fillColor('#0F766E').text('Touch of Cure', { align: 'center' });
      doc.fontSize(10).fillColor('#555').text('Physiotherapy at Home', { align: 'center' });
      doc.moveDown(1.5);

      doc.moveTo(50, doc.y).lineTo(545, doc.y).strokeColor('#0F766E').stroke();
      doc.moveDown(1);

      // Meta block
      doc.fontSize(11).fillColor('#111');
      doc.text(`Patient: ${data.patientName}`);
      const details = [
        data.patientAge !== null ? `${data.patientAge} years` : null,
        data.patientGender,
      ]
        .filter(Boolean)
        .join(' · ');
      if (details) doc.text(details);
      doc.text(`Therapist: ${data.therapistName}`);
      doc.text(`Date: ${data.issuedAt.toLocaleDateString('en-IN')}`);
      doc.moveDown(1);

      // Diagnosis
      doc.fontSize(13).fillColor('#0F766E').text('Diagnosis');
      doc.fontSize(11).fillColor('#111').text(data.diagnosis);
      doc.moveDown(0.8);

      // Advice
      if (data.advice) {
        doc.fontSize(13).fillColor('#0F766E').text('Advice');
        doc.fontSize(11).fillColor('#111').text(data.advice);
        doc.moveDown(0.8);
      }

      // Medicines
      if (data.medicines?.length) {
        doc.fontSize(13).fillColor('#0F766E').text('Medicines');
        doc.moveDown(0.3);
        doc.fontSize(11).fillColor('#111');
        data.medicines.forEach((medicine, index) => {
          const frequency = medicine.frequency ? ` (${medicine.frequency})` : '';
          doc.text(`${index + 1}. ${medicine.name} — ${medicine.dosage}${frequency}`);
        });
        doc.moveDown(1);
      }

      // Footer
      doc.moveDown(2);
      doc
        .fontSize(9)
        .fillColor('#777')
        .text(
          'This is a digitally generated prescription and does not require a physical signature.',
          { align: 'center' },
        );

      doc.end();
    });

    // PDFKit gives a Buffer, which the uploads service expects as a Multer-like file
    return this.uploads.uploadDocument(
      {
        buffer,
        mimetype: 'application/pdf',
        originalname: `prescription-${data.prescriptionId}.pdf`,
        size: buffer.length,
      } as Express.Multer.File,
      'prescriptions',
    );
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  private async scopeFor(
    userId: string,
    role: UserRole,
  ): Promise<Prisma.PrescriptionWhereInput> {
    if (role === UserRole.PATIENT) {
      const patient = await this.prisma.patient.findUnique({
        where: { userId },
        select: { id: true },
      });
      if (!patient) throw new NotFoundException('Patient profile not found');
      return { patientId: patient.id };
    }

    if (role === UserRole.THERAPIST) {
      const therapist = await this.prisma.therapist.findUnique({
        where: { userId },
        select: { id: true },
      });
      if (!therapist) throw new NotFoundException('Therapist profile not found');
      return { therapistId: therapist.id };
    }

    return {};
  }

  private ageFrom(dob: Date): number {
    return Math.floor((Date.now() - dob.getTime()) / (365.25 * 24 * 3600 * 1000));
  }
}
