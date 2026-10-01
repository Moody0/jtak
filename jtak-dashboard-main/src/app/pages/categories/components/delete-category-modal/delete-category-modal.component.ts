import { Component, Input, OnInit } from '@angular/core';
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
  isLoading$: Observable<boolean>;

  constructor(
    private service: CategoriesService,
    public modal: NgbActiveModal
  ) {}

  ngOnInit(): void {
    this.isLoading$ = this.service.isLoading$;
  }

  delete(): void {
    if (this.id) {
      this.service.delete(this.id).subscribe({
        next: () => this.modal.close(true),
        error: () => this.modal.dismiss(),
      });
    }
  }
}
