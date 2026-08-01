import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AppointmentStatus } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { CreateSlotDto, UpdateSlotDto } from './dto/availability.dto';

/** Booking granularity in minutes. */
const SLOT_SIZE_MINUTES = 30;
/** How far ahead patients may book. */
const MAX_ADVANCE_DAYS = 60;

@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  // -------------------------------------------------------
  // THERAPIST WEEKLY SCHEDULE
  // -------------------------------------------------------

  async listOwnSlots(userId: string) {
    const therapistId = await this.requireTherapistId(userId);
    return this.prisma.availabilitySlot.findMany({
      where: { therapistId },
      orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
    });
  }

  async createSlot(userId: string, dto: CreateSlotDto) {
    const therapistId = await this.requireTherapistId(userId);
    this.assertValidRange(dto.startTime, dto.endTime);

    // Reject windows that overlap an existing one on the same weekday
    const overlapping = await this.prisma.availabilitySlot.findMany({
      where: { therapistId, dayOfWeek: dto.dayOfWeek, isActive: true },
    });

    const newStart = this.toMinutes(dto.startTime);
    const newEnd = this.toMinutes(dto.endTime);

    const clash = overlapping.some((slot) => {
      const start = this.toMinutes(slot.startTime);
      const end = this.toMinutes(slot.endTime);
      return newStart < end && start < newEnd;
    });

    if (clash) {
      throw new BadRequestException('This time window overlaps an existing slot');
    }

    return this.prisma.availabilitySlot.create({
      data: {
        therapistId,
        dayOfWeek: dto.dayOfWeek,
        startTime: dto.startTime,
        endTime: dto.endTime,
      },
    });
  }

  async updateSlot(userId: string, slotId: string, dto: UpdateSlotDto) {
    const therapistId = await this.requireTherapistId(userId);
    const slot = await this.prisma.availabilitySlot.findFirst({
      where: { id: slotId, therapistId },
    });
    if (!slot) throw new NotFoundException('Availability slot not found');

    const startTime = dto.startTime ?? slot.startTime;
    const endTime = dto.endTime ?? slot.endTime;
    this.assertValidRange(startTime, endTime);

    return this.prisma.availabilitySlot.update({
      where: { id: slotId },
      data: { startTime, endTime, isActive: dto.isActive },
    });
  }

  async deleteSlot(userId: string, slotId: string) {
    const therapistId = await this.requireTherapistId(userId);
    const { count } = await this.prisma.availabilitySlot.deleteMany({
      where: { id: slotId, therapistId },
    });
    if (count === 0) throw new NotFoundException('Availability slot not found');
    return { message: 'Slot removed' };
  }

  /** Bulk save used by the therapist "My Availability" screen. */
  async replaceWeeklySchedule(userId: string, slots: CreateSlotDto[]) {
    const therapistId = await this.requireTherapistId(userId);

    for (const slot of slots) this.assertValidRange(slot.startTime, slot.endTime);

    await this.prisma.$transaction([
      this.prisma.availabilitySlot.deleteMany({ where: { therapistId } }),
      this.prisma.availabilitySlot.createMany({
        data: slots.map((s) => ({
          therapistId,
          dayOfWeek: s.dayOfWeek,
          startTime: s.startTime,
          endTime: s.endTime,
        })),
      }),
    ]);

    return this.prisma.availabilitySlot.findMany({
      where: { therapistId },
      orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
    });
  }

  // -------------------------------------------------------
  // PATIENT-FACING SLOT LOOKUP
  // -------------------------------------------------------

  /**
   * Expands the therapist's weekly windows for the requested date into
   * discrete 30-minute slots, then removes any slot already taken by a live
   * appointment and any slot in the past.
   */
  async getFreeSlots(therapistId: string, dateString: string) {
    const date = new Date(`${dateString}T00:00:00`);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException('Invalid date. Expected format YYYY-MM-DD');
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (date < today) throw new BadRequestException('Cannot fetch slots for a past date');

    const maxDate = new Date(today);
    maxDate.setDate(maxDate.getDate() + MAX_ADVANCE_DAYS);
    if (date > maxDate) {
      throw new BadRequestException(`Bookings open only ${MAX_ADVANCE_DAYS} days in advance`);
    }

    const therapist = await this.prisma.therapist.findUnique({
      where: { id: therapistId },
      select: { id: true, isAvailable: true },
    });
    if (!therapist) throw new NotFoundException('Therapist not found');
    if (!therapist.isAvailable) return { date: dateString, slots: [] };

    const windows = await this.prisma.availabilitySlot.findMany({
      where: { therapistId, dayOfWeek: date.getDay(), isActive: true },
      orderBy: { startTime: 'asc' },
    });

    // Statuses that still occupy the calendar
    const dayStart = new Date(date);
    const dayEnd = new Date(date);
    dayEnd.setHours(23, 59, 59, 999);

    const booked = await this.prisma.appointment.findMany({
      where: {
        therapistId,
        scheduledDate: { gte: dayStart, lte: dayEnd },
        status: {
          in: [
            AppointmentStatus.PENDING,
            AppointmentStatus.CONFIRMED,
            AppointmentStatus.IN_PROGRESS,
          ],
        },
      },
      select: { startTime: true, endTime: true },
    });

    const bookedRanges = booked.map((b) => ({
      start: this.toMinutes(b.startTime),
      end: this.toMinutes(b.endTime),
    }));

    const isToday = date.getTime() === today.getTime();
    const nowMinutes = new Date().getHours() * 60 + new Date().getMinutes();

    const slots: { startTime: string; endTime: string; available: boolean }[] = [];

    for (const window of windows) {
      const windowStart = this.toMinutes(window.startTime);
      const windowEnd = this.toMinutes(window.endTime);

      for (let t = windowStart; t + SLOT_SIZE_MINUTES <= windowEnd; t += SLOT_SIZE_MINUTES) {
        const slotEnd = t + SLOT_SIZE_MINUTES;

        const overlapsBooking = bookedRanges.some((r) => t < r.end && r.start < slotEnd);
        // Require at least 60 minutes of lead time for same-day bookings
        const tooSoon = isToday && t < nowMinutes + 60;

        slots.push({
          startTime: this.toTimeString(t),
          endTime: this.toTimeString(slotEnd),
          available: !overlapsBooking && !tooSoon,
        });
      }
    }

    return { date: dateString, slots };
  }

  /**
   * Authoritative check used by the booking flow right before persisting,
   * closing the race between viewing slots and confirming them.
   */
  async isSlotBookable(
    therapistId: string,
    scheduledDate: Date,
    startTime: string,
    endTime: string,
  ): Promise<boolean> {
    const windows = await this.prisma.availabilitySlot.findMany({
      where: { therapistId, dayOfWeek: scheduledDate.getDay(), isActive: true },
    });

    const start = this.toMinutes(startTime);
    const end = this.toMinutes(endTime);

    const insideWorkingHours = windows.some(
      (w) => this.toMinutes(w.startTime) <= start && end <= this.toMinutes(w.endTime),
    );
    if (!insideWorkingHours) return false;

    const dayStart = new Date(scheduledDate);
    dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(scheduledDate);
    dayEnd.setHours(23, 59, 59, 999);

    const clashes = await this.prisma.appointment.count({
      where: {
        therapistId,
        scheduledDate: { gte: dayStart, lte: dayEnd },
        status: {
          in: [
            AppointmentStatus.PENDING,
            AppointmentStatus.CONFIRMED,
            AppointmentStatus.IN_PROGRESS,
          ],
        },
        // String time comparison is safe because times are zero-padded HH:mm
        AND: [{ startTime: { lt: endTime } }, { endTime: { gt: startTime } }],
      },
    });

    return clashes === 0;
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  private async requireTherapistId(userId: string): Promise<string> {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');
    return therapist.id;
  }

  private assertValidRange(startTime: string, endTime: string) {
    const start = this.toMinutes(startTime);
    const end = this.toMinutes(endTime);

    if (end <= start) throw new BadRequestException('End time must be after start time');
    if ((end - start) % SLOT_SIZE_MINUTES !== 0) {
      throw new BadRequestException(
        `Window length must be a multiple of ${SLOT_SIZE_MINUTES} minutes`,
      );
    }
  }

  private toMinutes(time: string): number {
    const [hours, minutes] = time.split(':').map(Number);
    return hours * 60 + minutes;
  }

  private toTimeString(totalMinutes: number): string {
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  }
}
