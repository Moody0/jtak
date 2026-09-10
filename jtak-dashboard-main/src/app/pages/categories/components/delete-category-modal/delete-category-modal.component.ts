import { Component, Input, OnInit } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { CategoriesService } from '../../services/categories.service';

@Component({
  selector: 'app-delete-category-modal',
  templateUrl: './delete-category-modal.component.html',
  styles: [
  ]
})
export class DeleteCategoryModalComponent implements OnInit {
  @Input() id: number;

  constructor(
    private service: CategoriesService,
    public modal: NgbActiveModal) { }

  ngOnInit(): void {
  }

  delete() {
    if (this.id) {
      this.service
          .delete(this.id).subscribe(x => this.modal.dismiss());
    }
  }
}
