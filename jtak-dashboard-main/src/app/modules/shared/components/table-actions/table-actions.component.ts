import { Component, OnInit, Output, EventEmitter, Input } from '@angular/core';

@Component({
  selector: 'app-table-actions',
  templateUrl: './table-actions.component.html',
})
export class TableActionsComponent implements OnInit {
  @Output() deleteClicked = new EventEmitter();
  @Output() editClicked = new EventEmitter();
  @Output() viewClicked = new EventEmitter();
  @Input() showDeleteButton = true;
  @Input() showEditButton = true;
  @Input() showViewButton = false;

  constructor() {}

  ngOnInit(): void {}

  onEditClicked() {
    this.editClicked.emit();
  }

  onViewClicked() {
    this.viewClicked.emit();
  }

  onDeleteClicked() {
    this.deleteClicked.emit();
  }
}
