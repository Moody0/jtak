import { Component, Input, OnDestroy } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { SubSink } from 'subsink';
import { FilesService } from 'src/app/modules/shared/services/files.service';
import { RestaurantCategoryItem } from '../../models/restaurant-category.model';
import { RestaurantCategoriesService } from '../../services/restaurant-categories.service';

@Component({
  selector: 'app-delete-restaurant-category-modal',
  templateUrl: './delete-restaurant-category-modal.component.html',
  styleUrls: ['./delete-restaurant-category-modal.component.scss'],
})
export class DeleteRestaurantCategoryModalComponent implements OnDestroy {
  private subs = new SubSink();

  @Input() item!: RestaurantCategoryItem;
  isDeleting = false;

  constructor(
    public modal: NgbActiveModal,
    private service: RestaurantCategoriesService,
    public filesService: FilesService,
    private toastr: ToastrService
  ) {}

  getImageUrl(imagePath?: string): string {
    if (!imagePath || !imagePath.trim()) {
      return './assets/media/svg/files/blank-image.svg';
    }
    const val = imagePath.trim();
    if (val.startsWith('http://') || val.startsWith('https://') || val.startsWith('assets/') || val.startsWith('./assets/')) {
      return val;
    }
    return this.filesService.getFile(val, 100, 100);
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  confirm(): void {
    if (this.isDeleting || !this.item || !this.item.id) return;

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
