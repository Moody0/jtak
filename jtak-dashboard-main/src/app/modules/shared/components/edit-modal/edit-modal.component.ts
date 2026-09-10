import { Component, EventEmitter, Input, Output } from '@angular/core';

@Component({
  selector: 'app-edit-modal',
  templateUrl: './edit-modal.component.html',
})
export class EditModalComponent {
  @Input() item: any;
  @Input() itemName: string;
  @Input() moduleName: string;
  @Input() isLoading: boolean | null;
  @Input() saveDisabled: boolean;
  @Output() saveClicked = new EventEmitter();
  @Output() cancelClicked = new EventEmitter();

  constructor() {}

  onSaveClicked() {
    this.saveClicked.emit();
  }

  onCancelClicked() {
    this.cancelClicked.emit();
  }
}
