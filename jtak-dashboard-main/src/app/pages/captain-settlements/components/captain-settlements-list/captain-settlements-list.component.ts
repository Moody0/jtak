import { Component, OnInit, OnDestroy, TemplateRef } from '@angular/core';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { Subscription } from 'rxjs';
import { printDocument } from 'src/app/shared/printing/print-document';
import {
  CaptainSettlementsOverview,
  CaptainSettlementItem,
  CaptainOrdersSettlementDetail,
  CaptainOrderSettlementItem,
  SettlementBatchReceipt,
  CaptainLookupItem,
  ConfirmCaptainSettlementRequest,
} from '../../models/captain-settlement.model';
import { CaptainSettlementService } from '../../services/captain-settlement.service';

@Component({
  selector: 'app-captain-settlements-list',
  templateUrl: './captain-settlements-list.component.html',
  styleUrls: ['./captain-settlements-list.component.scss'],
})
export class CaptainSettlementsListComponent implements OnInit, OnDestroy {
  private subs = new Subscription();
  private summaryRequest?:Subscription;
  private ordersRequest?:Subscription;
  private receiptRequest?:Subscription;

  // Filters
  fromDate: string = '';
  toDate: string = '';
  selectedCaptainId: string = '';
  settlementStatus: string = 'unsettled';
  searchTerm: string = '';

  // Data
  captainsLookup: CaptainLookupItem[] = [];
  overview: CaptainSettlementsOverview | null = null;
  isLoading: boolean = false;
  errorMessage: string | null = null;

  // Selected Captain Orders Modal State
  selectedCaptainForOrders: CaptainSettlementItem | null = null;
  captainOrdersDetail: CaptainOrdersSettlementDetail | null = null;
  isLoadingOrders: boolean = false;
  selectedOrderIds: number[] = [];
  settlementNotes: string = '';
  isSettling: boolean = false;

  // Receipt Modal State
  selectedReceipt: SettlementBatchReceipt | null = null;
  isLoadingReceipt: boolean = false;

  constructor(
    private settlementService: CaptainSettlementService,
    private modalService: NgbModal
  ) {}

  ngOnInit(): void {
    this.initDefaultDates();
    this.loadCaptainsLookup();
    this.loadSummary();
  }

  initDefaultDates(): void {
    const today = new Date();
    const localDate=(date:Date)=>`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
    this.toDate = localDate(today);

    // Default to first day of the current month
    const firstDay = new Date(today.getFullYear(), today.getMonth(), 1);
    this.fromDate = localDate(firstDay);
  }

  loadCaptainsLookup(): void {
    this.subs.add(
      this.settlementService.getCaptains().subscribe({
        next: (captains) => {
          this.captainsLookup = captains;
        },
        error: (err) => {
          console.error('Failed to load captains lookup', err);
        },
      })
    );
  }

  loadSummary(): void {
    this.summaryRequest?.unsubscribe();
    if(this.fromDate && this.toDate && this.fromDate>this.toDate){this.errorMessage='تاريخ البداية يجب ألا يأتي بعد تاريخ النهاية.';this.isLoading=false;return;}
    this.isLoading = true;
    this.errorMessage = null;

    this.subs.add(
      this.summaryRequest=this.settlementService
        .getSummary({
          fromDate: this.fromDate,
          toDate: this.toDate,
          captainId: this.selectedCaptainId,
          settlementStatus: this.settlementStatus,
          searchTerm: this.searchTerm,
        })
        .subscribe({
          next: (res) => {
            this.overview = res;
            this.isLoading = false;
          },
          error: (err) => {
            this.isLoading = false;
            this.errorMessage = err?.error?.message || 'فشل تحميل بيانات تسويات الكباتن';
            console.error('Failed to load captain settlements summary', err);
          },
        })
    );
  }

  applyFilter(): void {
    this.loadSummary();
  }

  resetFilter(): void {
    this.initDefaultDates();
    this.selectedCaptainId = '';
    this.settlementStatus = 'unsettled';
    this.searchTerm = '';
    this.loadSummary();
  }

  openOrdersModal(
    captain: CaptainSettlementItem,
    content: TemplateRef<any>
  ): void {
    if(this.isSettling)return;
    this.ordersRequest?.unsubscribe();this.errorMessage=null;
    this.selectedCaptainForOrders = captain;
    this.captainOrdersDetail = null;
    this.selectedOrderIds = [];
    this.settlementNotes = '';
    this.isLoadingOrders = true;

    this.modalService.open(content, { size: 'xl', centered: true, scrollable: true, beforeDismiss:()=>!this.isSettling });

    this.subs.add(
      this.ordersRequest=this.settlementService
        .getCaptainOrders(captain.captainId, {
          fromDate: this.fromDate,
          toDate: this.toDate,
          settlementStatus: this.settlementStatus,
        })
        .subscribe({
          next: (detail) => {
            this.captainOrdersDetail = detail;
            this.isLoadingOrders = false;
            // Pre-select all unsettled orders by default
            this.selectedOrderIds = detail.orders
              .filter((o) => !o.isSettled)
              .map((o) => o.orderId);
          },
          error: (err) => {
            this.isLoadingOrders = false;
            this.errorMessage=err?.error?.message || 'تعذر تحميل طلبات الكابتن. حاول مرة أخرى.';
            console.error('Failed to load captain orders', err);
          },
        })
    );
  }

  toggleSelectAllOrders(): void {
    if(this.isSettling)return;
    if (!this.captainOrdersDetail) return;
    const unsettled = this.captainOrdersDetail.orders.filter((o) => !o.isSettled);
    if (this.selectedOrderIds.length === unsettled.length) {
      this.selectedOrderIds = [];
    } else {
      this.selectedOrderIds = unsettled.map((o) => o.orderId);
    }
  }

  isOrderSelected(orderId: number): boolean {
    return this.selectedOrderIds.includes(orderId);
  }

  toggleOrderSelection(orderId: number): void {
    if(this.isSettling)return;
    const idx = this.selectedOrderIds.indexOf(orderId);
    if (idx > -1) {
      this.selectedOrderIds.splice(idx, 1);
    } else {
      this.selectedOrderIds.push(orderId);
    }
  }

  getSelectedOrdersCount(): number {
    return this.selectedOrderIds.length;
  }

  getSelectedCashCollected(): number {
    if (!this.captainOrdersDetail) return 0;
    return this.captainOrdersDetail.orders
      .filter((o) => this.selectedOrderIds.includes(o.orderId))
      .reduce((sum, o) => sum + o.cashCollected, 0);
  }

  getSelectedCaptainEarnings(): number {
    if (!this.captainOrdersDetail) return 0;
    return this.captainOrdersDetail.orders
      .filter((o) => this.selectedOrderIds.includes(o.orderId))
      .reduce((sum, o) => sum + o.captainEarning, 0);
  }

  getSelectedNetDue(): number {
    return Math.max(0,this.getSelectedCashCollected() - this.getSelectedCaptainEarnings());
  }

  confirmSettlementFromModal(receiptModalTemplate: TemplateRef<any>, activeModal: any): void {
    if(this.isSettling)return;
    if (!this.selectedCaptainForOrders || this.selectedOrderIds.length === 0) {
      window.alert('يرجى تحديد طلب واحد على الأقل لإجراء التسوية');
      return;
    }

    const captainName = this.selectedCaptainForOrders.captainName;
    const count = this.selectedOrderIds.length;
    const netDue = this.getSelectedNetDue();

    const confirmed = window.confirm(
      `هل أنت متأكد من تأكيد تسوية ${count} طلب للكابتن "${captainName}"؟\nالمبلغ المطلوب تسليمه للشركة: ${netDue.toLocaleString()} ل.س`
    );

    if (!confirmed) return;

    this.isSettling = true;
    const req: ConfirmCaptainSettlementRequest = {
      captainId: this.selectedCaptainForOrders.captainId,
      orderIds: this.selectedOrderIds,
      notes: this.settlementNotes,
    };

    this.subs.add(
      this.settlementService.confirmSettlement(req).subscribe({
        next: (receipt) => {
          this.isSettling = false;
          activeModal.close();
          this.selectedReceipt = receipt;
          this.modalService.open(receiptModalTemplate, { size: 'lg', centered: true });
          this.loadSummary();
        },
        error: (err) => {
          this.isSettling = false;
          const msg = err?.error?.message || 'فشل تأكيد التسوية، يرجى المحاولة لاحقاً';
          window.alert(msg);
        },
      })
    );
  }

  confirmSettlementDirect(
    captain: CaptainSettlementItem,
    receiptModalTemplate: TemplateRef<any>
  ): void {
    const count = captain.unsettledOrdersCount;
    if(this.isSettling)return;
    if (count === 0) {
      window.alert('لا توجد طلبات غير مسوّاة لهذا الكابتن');
      return;
    }

    const confirmed = window.confirm(
      `تأكيد تسوية جميع الطلبات غير المسوّاة (${count} طلب) للكابتن "${captain.captainName}" في الفترة المحددة؟\nالمبلغ الصافي للشركة: ${captain.netDueToCompany.toLocaleString()} ل.س`
    );

    if (!confirmed) return;

    this.isSettling = true;
    const req: ConfirmCaptainSettlementRequest = {
      captainId: captain.captainId,
      fromDate: this.fromDate,
      toDate: this.toDate,
      notes: `تسوية سريعة لـ ${count} طلب للكابتن ${captain.captainName}`,
    };

    this.subs.add(
      this.settlementService.confirmSettlement(req).subscribe({
        next: (receipt) => {
          this.isSettling = false;
          this.selectedReceipt = receipt;
          this.modalService.open(receiptModalTemplate, { size: 'lg', centered: true });
          this.loadSummary();
        },
        error: (err) => {
          this.isSettling = false;
          const msg = err?.error?.message || 'فشل تأكيد التسوية';
          window.alert(msg);
        },
      })
    );
  }

  openReceiptModal(batchCode: string, content: TemplateRef<any>): void {
    if (!batchCode) return;
    this.receiptRequest?.unsubscribe();this.errorMessage=null;
    this.selectedReceipt = null;
    this.isLoadingReceipt = true;

    this.modalService.open(content, { size: 'lg', centered: true });

    this.subs.add(
      this.receiptRequest=this.settlementService.getBatchReceipt(batchCode).subscribe({
        next: (receipt) => {
          this.selectedReceipt = receipt;
          this.isLoadingReceipt = false;
        },
        error: (err) => {
          this.isLoadingReceipt = false;
          this.errorMessage=err?.error?.message || 'تعذر تحميل إيصال التسوية. حاول مرة أخرى.';
          console.error('Failed to load batch receipt', err);
        },
      })
    );
  }

  printReceipt(): void {
    printDocument('#printableReceiptArea');
  }

  getCompensationBadgeClass(type: number): string {
    switch (type) {
      case 0:
        return 'badge-light-primary text-primary';
      case 1:
        return 'badge-light-success text-success';
      case 2:
        return 'badge-light-info text-info';
      default:
        return 'badge-light-secondary';
    }
  }

  getStatusBadgeClass(status: string): string {
    switch (status) {
      case 'Settled':
        return 'badge-light-success text-success';
      case 'Unsettled':
        return 'badge-light-warning text-warning';
      default:
        return 'badge-light-secondary text-muted';
    }
  }

  getStatusDisplay(status: string): string {
    switch (status) {
      case 'Settled':
        return 'تمت التسوية';
      case 'Unsettled':
        return 'بانتظار التسوية';
      default:
        return 'لا توجد طلبات';
    }
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
