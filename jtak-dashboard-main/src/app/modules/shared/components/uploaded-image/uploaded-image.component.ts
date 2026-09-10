import { Component, EventEmitter, Input, Output } from '@angular/core';
import { FilesService } from '../../services/files.service';

@Component({
  selector: 'app-uploaded-image',
  templateUrl: './uploaded-image.component.html',
  styleUrls: ['./uploaded-image.component.scss'],
})
export class UploadedImageComponent {
  @Input() imageId: string;
  @Input() showDeleteButton = true;
  @Input() dimensions: { width: number; height: number };
  @Output() imageDeleted = new EventEmitter();

  constructor(public filesService: FilesService) {}

  onDeleteImageClicked() {
    this.imageDeleted.emit();
  }
}
