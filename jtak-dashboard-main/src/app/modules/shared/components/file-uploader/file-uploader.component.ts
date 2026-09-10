import { HttpEventType, HttpResponse } from '@angular/common/http';
import {
  ChangeDetectorRef,
  Component,
  EventEmitter,
  Input,
  Output,
} from '@angular/core';
import { ToastrService } from 'ngx-toastr';
import { Subscription } from 'rxjs';
import { finalize, tap } from 'rxjs/operators';
import { FilesService } from '../../services/files.service';

@Component({
  selector: 'app-file-uploader',
  templateUrl: './file-uploader.component.html',
  styleUrls: ['./file-uploader.component.scss'],
})
export class FileUploaderComponent {
  @Input() uploaderTitle: string;
  @Input() requiredFileType: string = 'image/*';
  @Input() multiple = true;
  @Output() fileUploaded = new EventEmitter();
  uploadProgress: number | null;
  uploadFinished: boolean;
  uploadSub: Subscription | null;

  constructor(
    private filesService: FilesService,
    private toasterService: ToastrService,
    private cdk: ChangeDetectorRef
  ) {}

  onFileSelected(event: any): void {
    const filesLength = event.target.files.length;

    const formData = new FormData();

    for (let i = 0; i < filesLength; i++) {
      if (
        this.requiredFileType === 'image/*' &&
        !this.isImage(event.target.files[i])
      ) {
        this.toasterService.error(
          `The file ${event.target.files[i].name} is not a valid image format`
        );
        return;
      }
      formData.append('file[]', event.target.files[i]);
    }


    const upload$ = this.filesService.uploadFile(formData, this.multiple).pipe(
      tap((evt) => {
        if (evt instanceof HttpResponse) {
          if (evt.body) {
            this.uploadFinished = true;
            this.toasterService.success('Uploaded Successfully');
            this.fileUploaded.emit(evt.body.split(","));
          }
        }
      }),
      finalize(() => this.reset())
    );

    this.uploadSub = upload$.subscribe((e) => {
      if (e.type === HttpEventType.UploadProgress) {
        this.uploadProgress = Math.round(100 * (e.loaded / e.total));
        this.cdk.detectChanges();
      }
    });
  }

  cancelUpload() {
    this.uploadSub?.unsubscribe();
    this.reset();
  }

  reset() {
    this.uploadProgress = null;
    this.uploadSub = null;
  }

  getFileExtension(file: any) {
    const parts = file.name.split('.');
    return parts[parts.length - 1];
  }

  isImage(file: any) {
    if (file?.type && file.type.startsWith('image/')) {
      return true;
    }
    const ext = this.getFileExtension(file);
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
      case 'bmp':
      case 'svg':
      case 'avif':
      case 'ico':
        return true;
    }
    return false;
  }
}
