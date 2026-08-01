import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';
import * as path from 'path';
import { FirebaseService } from '../notifications/firebase.service';

const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const ALLOWED_DOC_TYPES = ['application/pdf', 'image/jpeg', 'image/png'];
const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/quicktime'];

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);

  constructor(private readonly firebase: FirebaseService) {}

  async uploadImage(file: Express.Multer.File, folder: string): Promise<string> {
    this.validate(file, ALLOWED_IMAGE_TYPES, 5);
    return this.upload(file, folder);
  }

  /** Used for KYC documents and therapist certificates. */
  async uploadDocument(file: Express.Multer.File, folder: string): Promise<string> {
    this.validate(file, ALLOWED_DOC_TYPES, 10);
    return this.upload(file, folder);
  }

  async uploadVideo(file: Express.Multer.File, folder: string): Promise<string> {
    this.validate(file, ALLOWED_VIDEO_TYPES, 100);
    return this.upload(file, folder);
  }

  /**
   * Streams the buffer to Firebase Storage under a randomised filename and
   * returns a permanent download URL guarded by an unguessable token.
   */
  private async upload(file: Express.Multer.File, folder: string): Promise<string> {
    const bucket = this.firebase.getStorageBucket();
    const extension = path.extname(file.originalname) || this.extensionFor(file.mimetype);
    // Random filename prevents guessing other users' uploads by path
    const filename = `${folder}/${crypto.randomUUID()}${extension}`;
    const downloadToken = crypto.randomUUID();

    const blob = bucket.file(filename);

    await blob.save(file.buffer, {
      contentType: file.mimetype,
      resumable: false,
      metadata: {
        contentType: file.mimetype,
        metadata: { firebaseStorageDownloadTokens: downloadToken },
        cacheControl: 'public, max-age=31536000',
      },
    });

    return (
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
      `${encodeURIComponent(filename)}?alt=media&token=${downloadToken}`
    );
  }

  /** Removes a previously uploaded object given its public download URL. */
  async deleteByUrl(url: string): Promise<void> {
    try {
      const match = /\/o\/([^?]+)/.exec(url);
      if (!match) return;
      const objectPath = decodeURIComponent(match[1]);
      await this.firebase.getStorageBucket().file(objectPath).delete({ ignoreNotFound: true });
    } catch (error) {
      // Deleting storage must never block the surrounding business operation
      this.logger.warn(`Failed to delete storage object: ${(error as Error).message}`);
    }
  }

  private validate(file: Express.Multer.File, allowed: string[], maxMb: number) {
    if (!file?.buffer) throw new BadRequestException('No file was uploaded');
    if (!allowed.includes(file.mimetype)) {
      throw new BadRequestException(`Unsupported file type. Allowed: ${allowed.join(', ')}`);
    }
    if (file.size > maxMb * 1024 * 1024) {
      throw new BadRequestException(`File exceeds the ${maxMb} MB limit`);
    }
  }

  private extensionFor(mimetype: string): string {
    const map: Record<string, string> = {
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
      'application/pdf': '.pdf',
      'video/mp4': '.mp4',
      'video/quicktime': '.mov',
    };
    return map[mimetype] ?? '';
  }
}
