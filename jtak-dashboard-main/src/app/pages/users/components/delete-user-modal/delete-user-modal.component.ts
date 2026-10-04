import { Component, Input, OnInit, OnDestroy } from '@angular/core';
import { Subscription } from 'rxjs';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { UsersService } from '../../services/users.service';

@Component({
  selector: 'app-delete-user-modal',
  templateUrl: './delete-user-modal.component.html',
  styles: []
})
export class DeleteUserModalComponent implements OnInit,OnDestroy {
  isSaving=false;
  errorMessage='';
  private request?:Subscription;
  @Input() id: string;

  constructor(
    public service: UsersService,
    public modal: NgbActiveModal
  ) {}

  ngOnInit(): void {}

  delete() {
    if (this.id && !this.isSaving) {
      this.isSaving=true;this.errorMessage='';
      this.request=this.service.delete(this.id).subscribe({
        next: () => this.modal.close(),
        error: error=>{this.isSaving=false;this.errorMessage=error?.error?.message || error?.error?.errorDescription || (typeof error?.error==='string' ? error.error : 'تعذر أرشفة المستخدم. تحقق من السجل ثم حاول مجدداً.');}
      });
    }
  }
  ngOnDestroy():void {this.request?.unsubscribe();}
}
