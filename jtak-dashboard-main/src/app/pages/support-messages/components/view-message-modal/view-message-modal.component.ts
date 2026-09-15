import { Component, Input, OnInit, Output, EventEmitter } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { SupportMessage, SupportMessageStatus } from '../../models/support-message.model';
import { SupportMessagesService } from '../../services/support-messages.service';

@Component({
  selector: 'app-view-message-modal',
  templateUrl: './view-message-modal.component.html',
  styleUrls: ['./view-message-modal.component.scss'],
})
export class ViewMessageModalComponent implements OnInit {
  @Input() message: SupportMessage;
  @Output() updated = new EventEmitter<void>();

  SupportMessageStatus = SupportMessageStatus;
  selectedStatus: SupportMessageStatus;
  adminNotes: string = '';
  isSaving: boolean = false;

  constructor(
    public modal: NgbActiveModal,
    private supportService: SupportMessagesService,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    if (this.message) {
      this.selectedStatus = this.message.status;
      this.adminNotes = this.message.adminNotes || '';
    }
  }

  setStatus(status: SupportMessageStatus): void {
    this.selectedStatus = status;
  }

  saveChanges(): void {
    if (!this.message) return;
    this.isSaving = true;

    this.supportService
      .updateStatus(this.message.id, this.selectedStatus, this.adminNotes)
      .subscribe({
        next: () => {
          this.isSaving = false;
          this.message.status = this.selectedStatus;
          this.message.adminNotes = this.adminNotes;
          this.toastr.success('تم تحديث حالة الرسالة بنجاح', 'تم الحفظ');
          this.updated.emit();
          this.modal.close(true);
        },
        error: () => {
          this.isSaving = false;
          this.toastr.error('تعذر حفظ التعديلات، يرجى المحاولة لاحقاً', 'خطأ');
        },
      });
  }

  openWhatsApp(): void {
    if (!this.message?.senderPhone) return;
    let phone = this.message.senderPhone.replace(/\D/g, '');
    if (phone.startsWith('09')) {
      phone = '963' + phone.substring(1);
    } else if (phone.startsWith('00')) {
      phone = phone.substring(2);
    } else if (!phone.startsWith('963') && phone.length === 9) {
      phone = '963' + phone;
    }
    const text = encodeURIComponent(
      `مرحباً بك ${this.message.senderName}، نتواصل معك من فريق دعم تطبيق جيتك بخصوص استفسارك.`
    );
    window.open(`https://wa.me/${phone}?text=${text}`, '_blank');
  }

  callPhone(): void {
    if (!this.message?.senderPhone) return;
    window.open(`tel:${this.message.senderPhone}`, '_self');
  }
}
