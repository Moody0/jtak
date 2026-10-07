import { Component, Input, OnInit } from '@angular/core';
import { ToastrService } from 'ngx-toastr';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { Observable } from 'rxjs';
import { CategoriesService } from '../../services/categories.service';

@Component({
  selector: 'app-delete-category-modal',
  templateUrl: './delete-category-modal.component.html',
  styles: [
  ]
})
export class DeleteCategoryModalComponent implements OnInit {
  @Input() id: number;
  deleting = false;
  isLoading$: Observable<boolean>;

  constructor(
    private service: CategoriesService,
    public modal: NgbActiveModal, private toaster: ToastrService
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
  }

  delete(): void {
    if (this.deleting) return;
    if (this.id) {
      this.deleting = true;
      this.service.delete(this.id).subscribe({
        next: () => this.modal.close(true),
        error: (error) => {
          this.deleting = false;
          const body = error?.error;
          this.toaster.error(Array.isArray(body?.errors) ? body.errors.join('، ') : body?.message || body?.errorDescription || 'تعذر الحذف. حاول مرة أخرى.');
        },
      });
    }
  }
}
