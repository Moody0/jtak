import { Component, OnDestroy, OnInit } from '@angular/core';
import { SubSink } from 'subsink';
import { TableSelection } from 'src/app/modules/shared/utils/table-selection';
import { FormBuilder, FormGroup } from '@angular/forms';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import {
  SortState,
  ISortView,
  PaginatorState,
  IPaginatorView,
  ISearchView,
} from 'src/app/_metronic/shared/crud-table';
import { OrdersService } from '../../services/orders.service';
import { Order } from '../../models/orders.model';
import { EditDilevry } from './EditDilevry/edit-dilevry.component';
import { forkJoin, interval } from 'rxjs';
import { BulkConfirmModalComponent } from 'src/app/modules/shared/components/bulk-confirm-modal/bulk-confirm-modal.component';
import { DeleteModalComponent } from 'src/app/modules/shared/components/delete-modal/delete-modal.component';


@Component({
  selector: 'app-orders-list',
  templateUrl: './orders-list.component.html',
  styles: [
  ]
})
export class OrdersListComponent
  implements OnInit, OnDestroy, ISortView, IPaginatorView, ISearchView {
  private subs = new SubSink();
  selection = new TableSelection<any>((item) => item.id);
  isLoading: boolean;
  totalRecords: number;
  searchGroup: FormGroup;
  order: Order;

  constructor(
    private fb: FormBuilder,
    public ordersService: OrdersService,
    private modalService: NgbModal
  ) { }


  paginator: PaginatorState;
  paginate(paginator: PaginatorState) {
    this.selection.clear();
    this.ordersService.patchState({ paginator });
  }

  sorting: SortState;
  sort(column: string): void {
    this.selection.clear();
    const sorting = this.sorting;
    const isActiveColumn = sorting.column === column;
    if (!isActiveColumn) {
      sorting.column = column;
      sorting.direction = 'ASC';
    } else {
      sorting.direction = sorting.direction === 'ASC' ? 'DESC' : 'ASC';
    }

    this.ordersService.patchState({ sorting });
  }

  searchForm() {
    this.searchGroup = this.fb.group({
      searchTerm: [''],
    });
    this.subs.sink = this.searchGroup.controls.searchTerm.valueChanges
      .pipe(debounceTime(500), distinctUntilChanged())
      .subscribe((val) => this.search(val));
  }

  search(searchTerm: string) {
    this.selection.clear();
    this.ordersService.patchState({ searchTerm });
  }
  confirmCancel(orderId: number): void {
    const modalRef = this.modalService.open(DeleteModalComponent);
    modalRef.componentInstance.title = `Cancel order #${orderId}?`;
    modalRef.componentInstance.confirmationText = 'This stops fulfillment for the entire order. This action cannot be undone.';
    modalRef.componentInstance.deletingText = 'Cancelling order…';
    modalRef.componentInstance.confirmLabel = 'Cancel order';
    this.subs.sink = modalRef.componentInstance.cancelClicked.subscribe(() => modalRef.dismiss());
    this.subs.sink = modalRef.componentInstance.deleteClicked.subscribe(() => {
      modalRef.componentInstance.isLoading = true;
      this.ordersService.cancel(orderId).subscribe(res => {
        if (res === true) {
          modalRef.close();
          this.ordersService.fetchPost();
        }
      });
    });
  }

  approve(order: Order): void {
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = 1;
    modalRef.componentInstance.itemLabel = 'order';
    modalRef.componentInstance.actionLabel = 'Approve order';
    modalRef.componentInstance.description = `Approve order #${order.id} and send it to the nearest available delivery driver?`;
    modalRef.componentInstance.action = () => this.ordersService.approve(order.id);
    modalRef.result.then(() => this.ordersService.fetchPost(), () => {});
  }

  canApprove(order: Order): boolean {
    return order.orderDetails?.some((detail) => detail.orderDetailStatus === 0) ?? false;
  }

  bulkCancel(items: Order[]): void {
    const selected = this.selection.selectedItems(items);
    if (!selected.length) return;
    const modalRef = this.modalService.open(BulkConfirmModalComponent);
    modalRef.componentInstance.count = selected.length;
    modalRef.componentInstance.itemLabel = selected.length === 1 ? 'order' : 'orders';
    modalRef.componentInstance.actionLabel = 'Cancel';
    modalRef.componentInstance.description = 'This stops fulfillment for every selected order. This action cannot be undone.';
    modalRef.componentInstance.action = () => forkJoin(selected.map((item) => this.ordersService.cancel(item.id)));
    modalRef.result.then(() => { this.selection.clear(); this.ordersService.fetchPost(); }, () => {});
  }

  edit(item: Order) {
    const modalRef = this.modalService.open(EditDilevry, {
      size: 'lg',
    });
    modalRef.componentInstance.item = item;
    modalRef.result.then(
      () => this.ordersService.fetchPost(),
      () => { }
    );
  }
  ngOnInit(): void {
    this.ordersService.setDefaults();
    this.searchForm();
    this.ordersService.fetchPost();
    this.subs.sink = interval(5000).subscribe(() => this.ordersService.fetchPost());
    this.subs.sink = this.ordersService.isLoading$.subscribe(res => this.isLoading = res);
    this.sorting = this.ordersService.sorting;
    this.paginator = this.ordersService.paginator;
  }
  isDeliveryEditable(order: Order) {
    for (let orderDetail of order.orderDetails) {
      if(orderDetail.orderDetailStatus != 4 && orderDetail.orderDetailStatus != 1){
        return false;
      }
    }
    return true;
  }
  ngOnDestroy() {
    this.subs.unsubscribe();
  }
}
