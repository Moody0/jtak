import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { UsersService } from '../../services/users.service';

@Component({
  selector: 'app-delete-user-modal',
  templateUrl: './delete-user-modal.component.html',
  styles: []
})
export class DeleteUserModalComponent implements OnInit {
  @Input() id: string;

  constructor(
    public service: UsersService,
    public modal: NgbActiveModal
  ) {}

  ngOnInit(): void {}

  delete() {
    if (this.id) {
      this.service.delete(this.id).subscribe({
        next: () => this.modal.close(),
        error: () => this.modal.dismiss()
      });
    }
  }
}
