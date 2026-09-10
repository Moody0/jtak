import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { SubmitButtonComponent } from './components/submit-button/submit-button.component';
import { InputContainerComponent } from './components/input-container/input-container.component';
import { TableActionsComponent } from './components/table-actions/table-actions.component';
import { InlineSVGModule } from 'ng-inline-svg';
import { FileUploaderComponent } from './components/file-uploader/file-uploader.component';
import { MaterialModule } from '../material/material.module';
import { UploadedImageComponent } from './components/uploaded-image/uploaded-image.component';
import { SpinnerComponent } from './components/spinner/spinner.component';
import { ModalProgressComponent } from './components/modal-progress/modal-progress.component';
import { DeleteModalComponent } from './components/delete-modal/delete-modal.component';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { EditModalComponent } from './components/edit-modal/edit-modal.component';
import { StarRatingComponent } from './components/star-rating/star-rating.component';
import { BulkConfirmModalComponent } from './components/bulk-confirm-modal/bulk-confirm-modal.component';

@NgModule({
  declarations: [
    SubmitButtonComponent,
    InputContainerComponent,
    TableActionsComponent,
    FileUploaderComponent,
    UploadedImageComponent,
    SpinnerComponent,
    ModalProgressComponent,
    DeleteModalComponent,
    EditModalComponent,
    StarRatingComponent,
    BulkConfirmModalComponent,
  ],
  imports: [CommonModule, InlineSVGModule, MaterialModule, NgbModalModule],
  exports: [
    SubmitButtonComponent,
    InputContainerComponent,
    TableActionsComponent,
    FileUploaderComponent,
    UploadedImageComponent,
    SpinnerComponent,
    MaterialModule,
    EditModalComponent,
    DeleteModalComponent,
    StarRatingComponent,
    BulkConfirmModalComponent,
  ],
})
export class SharedModule {}
