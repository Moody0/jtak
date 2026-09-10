import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { PageSizes, PaginatorState } from '../../models/paginator.model';

@Component({
  selector: 'app-paginator',
  templateUrl: './paginator.view.html',
  styleUrls: ['./paginator.component.scss'],
})
export class PaginatorComponent implements OnInit {
  @Input() paginator: PaginatorState;
  @Input() isLoading: boolean;
  @Output() paginate: EventEmitter<PaginatorState> = new EventEmitter();
  pageSizes: number[] = PageSizes;
  constructor() {}

  ngOnInit(): void {}

  pageChange(num: number) {
    this.paginator.page = num;
    this.paginate.emit(this.paginator);
  }

  sizeChange() {
    this.paginator.pageSize = +this.paginator.pageSize;
    this.paginator.page = 0;
    this.paginate.emit(this.paginator);
  }
}
