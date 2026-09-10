import { Component, EventEmitter, Input, Output } from '@angular/core';

@Component({
  selector: 'app-delete-modal',
  templateUrl: './delete-modal.component.html',
})
export class DeleteModalComponent {

  @Input() isLoading: boolean | null;
  @Input() moduleName: string;
  @Input() title: string;
  @Input() deletingText: string;
  @Input() confirmationText: string;
  @Input() confirmLabel: string = 'Delete';
  @Output() deleteClicked = new EventEmitter();
  @Output() cancelClicked = new EventEmitter();

  constructor() { }


  onDeleteClicked() {
    this.deleteClicked.emit();
  }


  onCancelClicked() {
    this.cancelClicked.emit();
  }


}
