import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { CreateAddressDto, UpdateAddressDto } from './dto/patient.dto';

@Injectable()
export class PatientsService {
  constructor(private readonly prisma: PrismaService) {}

  private async requirePatientId(userId: string): Promise<string> {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');
    return patient.id;
  }

  async listAddresses(userId: string) {
    const patientId = await this.requirePatientId(userId);
    return this.prisma.address.findMany({
      where: { patientId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
  }

  async createAddress(userId: string, dto: CreateAddressDto) {
    const patientId = await this.requirePatientId(userId);

    const existingCount = await this.prisma.address.count({ where: { patientId } });
    // The first address a patient saves automatically becomes the default
    const shouldBeDefault = dto.isDefault || existingCount === 0;

    return this.prisma.$transaction(async (tx) => {
      if (shouldBeDefault) {
        await tx.address.updateMany({ where: { patientId }, data: { isDefault: false } });
      }
      return tx.address.create({
        data: { patientId, ...dto, isDefault: shouldBeDefault },
      });
    });
  }

  async updateAddress(userId: string, addressId: string, dto: UpdateAddressDto) {
    const patientId = await this.requirePatientId(userId);

    const address = await this.prisma.address.findFirst({
      where: { id: addressId, patientId },
      select: { id: true },
    });
    if (!address) throw new NotFoundException('Address not found');

    return this.prisma.$transaction(async (tx) => {
      if (dto.isDefault) {
        await tx.address.updateMany({ where: { patientId }, data: { isDefault: false } });
      }
      return tx.address.update({ where: { id: addressId }, data: dto });
    });
  }

  async deleteAddress(userId: string, addressId: string) {
    const patientId = await this.requirePatientId(userId);

    const address = await this.prisma.address.findFirst({
      where: { id: addressId, patientId },
    });
    if (!address) throw new NotFoundException('Address not found');

    await this.prisma.address.delete({ where: { id: addressId } });

    // Promote another address to default if the default one was removed
    if (address.isDefault) {
      const next = await this.prisma.address.findFirst({
        where: { patientId },
        orderBy: { createdAt: 'desc' },
        select: { id: true },
      });
      if (next) {
        await this.prisma.address.update({
          where: { id: next.id },
          data: { isDefault: true },
        });
      }
    }

    return { message: 'Address deleted' };
  }

  /** Referral screen: code plus how many people have signed up with it. */
  async getReferralInfo(userId: string) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true, referralCode: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    const referredCount = await this.prisma.patient.count({
      where: { referredById: patient.id },
    });

    return {
      referralCode: patient.referralCode,
      referredCount,
      bonusPerReferral: Number(process.env.REFERRAL_BONUS ?? 100),
    };
  }

  /** Patient history shown to a therapist inside the patient profile screen. */
  async getPatientHistoryForTherapist(therapistUserId: string, patientId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    // A therapist may only view patients they have actually treated
    const treated = await this.prisma.appointment.count({
      where: { therapistId: therapist.id, patientId },
    });
    if (treated === 0) throw new NotFoundException('Patient not found in your records');

    const patient = await this.prisma.patient.findUnique({
      where: { id: patientId },
      select: {
        id: true,
        dateOfBirth: true,
        gender: true,
        medicalHistory: true,
        user: { select: { fullName: true, phone: true, avatarUrl: true } },
        appointments: {
          where: { therapistId: therapist.id },
          orderBy: { scheduledDate: 'desc' },
          select: {
            id: true,
            type: true,
            status: true,
            scheduledDate: true,
            startTime: true,
            problem: true,
          },
        },
        prescriptions: {
          orderBy: { createdAt: 'desc' },
          select: { id: true, diagnosis: true, advice: true, medicines: true, createdAt: true },
        },
        progressLogs: {
          orderBy: { loggedAt: 'desc' },
          take: 30,
          select: { id: true, condition: true, painLevel: true, loggedAt: true },
        },
      },
    });

    return patient;
  }

  /** Therapist "My Patients" list, derived from their appointment history. */
  async listTherapistPatients(therapistUserId: string, search?: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const patients = await this.prisma.patient.findMany({
      where: {
        appointments: { some: { therapistId: therapist.id } },
        ...(search
          ? { user: { fullName: { contains: search } } }
          : {}),
      },
      select: {
        id: true,
        gender: true,
        dateOfBirth: true,
        user: { select: { fullName: true, avatarUrl: true, phone: true } },
        appointments: {
          where: { therapistId: therapist.id },
          orderBy: { scheduledDate: 'desc' },
          take: 1,
          select: { scheduledDate: true, problem: true },
        },
      },
    });

    return patients.map((p) => ({
      id: p.id,
      fullName: p.user.fullName,
      avatarUrl: p.user.avatarUrl,
      phone: p.user.phone,
      gender: p.gender,
      age: p.dateOfBirth ? this.ageFrom(p.dateOfBirth) : null,
      lastAppointment: p.appointments[0]?.scheduledDate ?? null,
      lastProblem: p.appointments[0]?.problem ?? null,
    }));
  }

  private ageFrom(dob: Date): number {
    const diff = Date.now() - dob.getTime();
    return Math.floor(diff / (365.25 * 24 * 3600 * 1000));
  }
}
