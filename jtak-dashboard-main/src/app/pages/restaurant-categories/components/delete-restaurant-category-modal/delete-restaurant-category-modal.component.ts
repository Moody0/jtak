import { Component, Input, OnDestroy } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { SubSink } from 'subsink';
import { RestaurantCategoryItem } from '../../models/restaurant-category.model';
import { RestaurantCategoriesService } from '../../services/restaurant-categories.service';

@Component({
  selector: 'app-delete-restaurant-category-modal',
  templateUrl: './delete-restaurant-category-modal.component.html',
})
export class DeleteRestaurantCategoryModalComponent implements OnDestroy {
  private subs = new SubSink();

  @Input() item!: RestaurantCategoryItem;
  isDeleting = false;

  constructor(
    public modal: NgbActiveModal,
    private service: RestaurantCategoriesService,
    private toastr: ToastrService
  ) {}

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  confirm(): void {
    if (!this.item || !this.item.id) return;

    this.isDeleting = true;
    this.subs.sink = this.service.deleteItem(this.item.id).subscribe({
      next: () => {
        this.isDeleting = false;
        this.toastr.success('تم حذف التصنيف بنجاح');
        this.modal.close(true);
      },
      error: () => {
        this.isDeleting = false;
        this.toastr.error('تعذر حذف التصنيف. حاول مرة أخرى.');
      },
    });
  }
}
