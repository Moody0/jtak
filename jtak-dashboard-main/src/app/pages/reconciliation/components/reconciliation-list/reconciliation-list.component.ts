import { Component, OnInit, OnDestroy, ChangeDetectorRef, ViewChild, TemplateRef } from '@angular/core';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { interval } from 'rxjs';
import {
  CaptainSettlementSummary,
  CaptainShiftDetails,
  DailySettlementBatch,
  SettleCaptainShiftRequest,
  SettlementResult,
  SettlementRequestItem,
  SettlementRequestStatus,
  SettlementPartyType,
  MerchantReconciliationSummary,
  MerchantReconciliationItem,
  MerchantReconciliationDataTableRequest,
  MerchantReconciliationDataTableResult,
  MerchantStatement,
  MerchantStatementTransaction,
  MerchantSettlementHistoryItem,
  SettlementHistoryItem,
  SettlementHistorySummary,
  SettlementHistoryDataTableRequest,
  SettlementHistoryDataTableResult,
  SettlementReceipt,
  SettlementHistoryPartyFilter,
} from '../../models/reconciliation.model';
import { ReconciliationService } from '../../services/reconciliation.service';
import { NotificationSummaryService } from 'src/app/_metronic/layout/core/notification-summary.service';

@Component({
  selector: 'app-reconciliation-list',
  templateUrl: './reconciliation-list.component.html',
  styleUrls: ['./reconciliation-list.component.scss'],
})
export class ReconciliationListComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  private isPollingRequests = false;
  private isPollingCaptains = false;
  private isPollingHistory = false;
  private isPollingMerchants = false;

  activeTab: 'merchants' | 'couriers' | 'history' = 'merchants';

  // Merchant Reconciliation State
  merchantSummary: MerchantReconciliationSummary | null = null;
  merchantsList: MerchantReconciliationItem[] = [];
  merchantTotalRecords: number = 0;
  merchantPageNumber: number = 1;
  merchantPageSize: number = 10;
  merchantSearchTerm: string = '';
  isLoadingMerchants: boolean = false;
  isLoadingMerchantSummary: boolean = false;

  // Merchant Statement Modal State
  selectedMerchantForStatement: MerchantReconciliationItem | null = null;
  merchantStatementData: MerchantStatement | null = null;
  isLoadingMerchantStatement: boolean = false;
  statementSearchTerm: string = '';
  statementActiveTab: 'statement' | 'settlements' = 'statement';

  // Captain Reconciliation State
  captains: CaptainSettlementSummary[] = [];
  filteredCaptains: CaptainSettlementSummary[] = [];
  history: DailySettlementBatch[] = [];
  settlementRequests: SettlementRequestItem[] = [];
  isLoadingRequests = false;
  processingRequestId: string | null = null;
  readonly requestStatus = SettlementRequestStatus;
  readonly partyType = SettlementPartyType;

  // Settlement Payment History State
  historyItems: SettlementHistoryItem[] = [];
  historySummary: SettlementHistorySummary | null = null;
  historyTotalRecords: number = 0;
  historyPage: number = 1;
  historyPageSize: number = 10;
  historySearchTerm: string = '';
  historyPartyFilter: SettlementHistoryPartyFilter = SettlementHistoryPartyFilter.All;
  historyFromDate: string = '';
  historyToDate: string = '';
  isLoadingHistory: boolean = false;
  selectedReceipt: SettlementReceipt | null = null;
  isLoadingReceipt: boolean = false;
  isPrintingHistory: boolean = false;
  historyPrintItems: SettlementHistoryItem[] = [];
  readonly historyPartyFilterEnum = SettlementHistoryPartyFilter;
  now: Date = new Date();

  get merchantRequests(): SettlementRequestItem[] {
    return this.settlementRequests.filter(r => r.partyType === SettlementPartyType.Merchant);
  }

  get pendingMerchantRequestsCount(): number {
    return this.merchantRequests.filter(r => r.status === SettlementRequestStatus.Pending).length;
  }

  get courierRequests(): SettlementRequestItem[] {
    return this.settlementRequests.filter(r => r.partyType === SettlementPartyType.Captain);
  }

  get pendingCourierRequestsCount(): number {
    return this.courierRequests.filter(r => r.status === SettlementRequestStatus.Pending).length;
  }

  isLoading: boolean = false;
  searchTerm: string = '';

  // Settlement Form State
  selectedCaptain: CaptainSettlementSummary | null = null;
  settleCashReceived: number = 0;
  settleNotes: string = '';
  settleReason: string = '';
  isSettling: boolean = false;
  settlementError: string | null = null;
  settlementSuccess: SettlementResult | null = null;

  // Statement State
  statementDetails: CaptainShiftDetails | null = null;
  isLoadingStatement: boolean = false;

  constructor(
    private reconciliationService: ReconciliationService,
    private modalService: NgbModal,
    private cdr: ChangeDetectorRef,
    private notificationSummaryService: NotificationSummaryService
  ) {}

  ngOnInit(): void {
    this.loadMerchantSummary();
    this.loadMerchants();
    this.loadCaptains();
    this.loadHistory();
    this.loadSettlementRequests();
    this.startAutoRefresh();
  }

  startAutoRefresh(): void {
    this.subs.sink = interval(5000).subscribe(() => {
      // Avoid interrupting the user if a modal is open or an action is currently processing
      if (this.modalService.hasOpenModals() || this.processingRequestId || this.isSettling) {
        return;
      }
      this.pollSettlementRequests();
      if (this.activeTab === 'merchants') {
        this.pollMerchants();
      } else if (this.activeTab === 'couriers') {
        this.pollCaptains();
      } else if (this.activeTab === 'history') {
        this.pollHistory();
      }
      this.notificationSummaryService.refresh();
    });
  }

  loadMerchantSummary(): void {
    this.isLoadingMerchantSummary = true;
    this.reconciliationService.getMerchantSummary().subscribe({
      next: (summary) => {
        this.merchantSummary = summary;
        this.isLoadingMerchantSummary = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load merchant reconciliation summary', err);
        this.isLoadingMerchantSummary = false;
        this.cdr.detectChanges();
      },
    });
  }

  loadMerchants(): void {
    this.isLoadingMerchants = true;
    const req: MerchantReconciliationDataTableRequest = {
      pageNumber: this.merchantPageNumber,
      pageSize: this.merchantPageSize,
      search: this.merchantSearchTerm,
    };
    this.reconciliationService.getMerchantReconciliationDataTable(req).subscribe({
      next: (res) => {
        this.merchantsList = res.items || [];
        this.merchantTotalRecords = res.totalRecords || 0;
        this.isLoadingMerchants = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load merchants list', err);
        this.isLoadingMerchants = false;
        this.cdr.detectChanges();
      },
    });
  }

  pollMerchants(): void {
    if (this.isPollingMerchants) return;
    this.isPollingMerchants = true;
    this.reconciliationService.getMerchantSummary().subscribe({
      next: (s) => {
        this.merchantSummary = s;
        const req: MerchantReconciliationDataTableRequest = {
          pageNumber: this.merchantPageNumber,
          pageSize: this.merchantPageSize,
          search: this.merchantSearchTerm,
        };
        this.reconciliationService.getMerchantReconciliationDataTable(req).subscribe({
          next: (res) => {
            this.merchantsList = res.items || [];
            this.merchantTotalRecords = res.totalRecords || 0;
            this.isPollingMerchants = false;
            this.cdr.detectChanges();
          },
          error: () => {
            this.isPollingMerchants = false;
          },
        });
      },
      error: () => {
        this.isPollingMerchants = false;
      },
    });
  }

  onMerchantSearch(): void {
    this.merchantPageNumber = 1;
    this.loadMerchants();
  }

  onMerchantPageChange(page: number): void {
    if (page < 1 || page > this.totalMerchantPages) return;
    this.merchantPageNumber = page;
    this.loadMerchants();
  }

  get totalMerchantPages(): number {
    return Math.ceil(this.merchantTotalRecords / this.merchantPageSize) || 1;
  }

  get merchantPagesArray(): number[] {
    const total = this.totalMerchantPages;
    const current = this.merchantPageNumber;
    const delta = 2;
    const range: number[] = [];
    for (let i = Math.max(1, current - delta); i <= Math.min(total, current + delta); i++) {
      range.push(i);
    }
    return range;
  }

  openMerchantStatement(content: TemplateRef<any>, merchant: MerchantReconciliationItem): void {
    this.selectedMerchantForStatement = merchant;
    this.statementSearchTerm = '';
    this.statementActiveTab = 'statement';
    this.merchantStatementData = null;
    this.isLoadingMerchantStatement = true;

    this.modalService.open(content, { size: 'xl', centered: true, scrollable: true });

    this.loadMerchantStatementData(merchant.merchantId);
  }

  loadMerchantStatementData(merchantId: number, search?: string): void {
    this.isLoadingMerchantStatement = true;
    this.reconciliationService.getMerchantStatement(merchantId, search).subscribe({
      next: (stmt) => {
        this.merchantStatementData = stmt;
        this.isLoadingMerchantStatement = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load merchant statement', err);
        this.isLoadingMerchantStatement = false;
        this.cdr.detectChanges();
      },
    });
  }

  onStatementSearch(): void {
    if (!this.selectedMerchantForStatement) return;
    this.loadMerchantStatementData(this.selectedMerchantForStatement.merchantId, this.statementSearchTerm);
  }

  clearStatementSearch(): void {
    this.statementSearchTerm = '';
    if (this.selectedMerchantForStatement) {
      this.loadMerchantStatementData(this.selectedMerchantForStatement.merchantId);
    }
  }

  pollSettlementRequests(): void {
    if (this.isPollingRequests) return;
    this.isPollingRequests = true;
    this.reconciliationService.getSettlementRequests().subscribe({
      next: (items) => {
        this.settlementRequests = items || [];
        this.isPollingRequests = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isPollingRequests = false;
      },
    });
  }

  pollCaptains(): void {
    if (this.isPollingCaptains) return;
    this.isPollingCaptains = true;
    this.reconciliationService.getCaptains().subscribe({
      next: (data) => {
        this.captains = data || [];
        this.applyFilter();
        this.isPollingCaptains = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isPollingCaptains = false;
      },
    });
  }

  pollHistory(): void {
    if (this.isPollingHistory) return;
    this.isPollingHistory = true;
    const req: SettlementHistoryDataTableRequest = {
      page: this.historyPage,
      pageSize: this.historyPageSize,
      searchTerm: this.historySearchTerm,
      partyFilter: this.historyPartyFilter,
      fromDate: this.historyFromDate || undefined,
      toDate: this.historyToDate || undefined,
      sortColumn: 'CompletedAt',
      sortDirection: 'DESC',
    };
    this.reconciliationService.getSettlementHistoryDataTable(req).subscribe({
      next: (res) => {
        this.historyItems = res.items || [];
        this.historyTotalRecords = res.totalRecords || 0;
        this.historySummary = res.summary || null;
        this.isPollingHistory = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isPollingHistory = false;
      },
    });
  }

  loadSettlementRequests(): void {
    this.isLoadingRequests = true;
    this.reconciliationService.getSettlementRequests().subscribe({
      next: (items) => {
        this.settlementRequests = items || [];
        this.isLoadingRequests = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoadingRequests = false;
        this.cdr.detectChanges();
      },
    });
  }

  acceptSettlementRequest(item: SettlementRequestItem): void {
    const message = item.partyType === SettlementPartyType.Captain
      ? `تأكيد استلام ${item.amount.toLocaleString()} ل.س من المندوب؟ سيتم تصفير عهدته وإضافة المبلغ لخزنة جيتك.`
      : `قبول طلب التاجر ${item.requestNumber}؟ سيبقى المبلغ محجوزاً حتى تأكيد الاستلام.`;
    if (!window.confirm(message)) return;
    this.processingRequestId = item.id;
    this.reconciliationService.acceptRequest(item.id).subscribe({
      next: () => this.finishRequestAction(),
      error: (err) => this.failRequestAction(err),
    });
  }

  rejectSettlementRequest(item: SettlementRequestItem): void {
    const reason = window.prompt('اكتب سبب رفض طلب التسوية (سيصل لصاحب الطلب):');
    if (reason === null || !reason.trim()) return;
    this.processingRequestId = item.id;
    this.reconciliationService.rejectRequest(item.id, reason.trim()).subscribe({
      next: () => this.finishRequestAction(),
      error: (err) => this.failRequestAction(err),
    });
  }

  completeMerchantSettlement(item: SettlementRequestItem): void {
    if (!window.confirm(`تأكيد أن التاجر استلم ${item.amount.toLocaleString()} ل.س؟ سيتم خصم المبلغ من خزنة جيتك وإغلاق التسوية.`)) return;
    this.processingRequestId = item.id;
    this.reconciliationService.completeMerchantRequest(item.id).subscribe({
      next: () => this.finishRequestAction(),
      error: (err) => this.failRequestAction(err),
    });
  }

  requestStatusLabel(status: SettlementRequestStatus): string {
    switch (status) {
      case SettlementRequestStatus.Pending: return 'قيد المراجعة';
      case SettlementRequestStatus.Approved: return 'مقبول — بانتظار الاستلام';
      case SettlementRequestStatus.Rejected: return 'مرفوض';
      case SettlementRequestStatus.Completed: return 'مكتمل';
      default: return '-';
    }
  }

  private finishRequestAction(): void {
    this.processingRequestId = null;
    this.loadSettlementRequests();
    this.loadMerchantSummary();
    this.loadMerchants();
    this.loadCaptains();
    this.loadHistory();
    this.notificationSummaryService.refresh();
  }

  private failRequestAction(err: any): void {
    this.processingRequestId = null;
    let msg = 'تعذر تنفيذ العملية';
    if (typeof err?.error === 'string') {
      msg = err.error;
    } else if (err?.error?.message) {
      msg = err.error.message;
    } else if (err?.error?.title) {
      msg = err.error.title;
    } else if (err?.message && !err.message.includes('Http failure')) {
      msg = err.message;
    }
    window.alert(msg);
    this.cdr.detectChanges();
  }

  loadCaptains(): void {
    this.isLoading = true;
    this.reconciliationService.getCaptains().subscribe({
      next: (data) => {
        this.captains = data || [];
        this.applyFilter();
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load fleet reconciliation summaries', err);
        this.isLoading = false;
        this.cdr.detectChanges();
      },
    });
  }

  loadHistory(): void {
    this.isLoadingHistory = true;
    const req: SettlementHistoryDataTableRequest = {
      page: this.historyPage,
      pageSize: this.historyPageSize,
      searchTerm: this.historySearchTerm,
      partyFilter: this.historyPartyFilter,
      fromDate: this.historyFromDate || undefined,
      toDate: this.historyToDate || undefined,
      sortColumn: 'CompletedAt',
      sortDirection: 'DESC',
    };
    this.reconciliationService.getSettlementHistoryDataTable(req).subscribe({
      next: (res) => {
        this.historyItems = res.items || [];
        this.historyTotalRecords = res.totalRecords || 0;
        this.historySummary = res.summary || null;
        this.isLoadingHistory = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load settlement history', err);
        this.isLoadingHistory = false;
        this.cdr.detectChanges();
      },
    });
  }

  onHistoryPartyFilterChange(filter: SettlementHistoryPartyFilter): void {
    this.historyPartyFilter = filter;
    this.historyPage = 1;
    this.loadHistory();
  }

  onHistoryDateChange(): void {
    this.historyPage = 1;
    this.loadHistory();
  }

  onHistorySearch(): void {
    this.historyPage = 1;
    this.loadHistory();
  }

  clearHistorySearch(): void {
    this.historySearchTerm = '';
    this.historyPage = 1;
    this.loadHistory();
  }

  clearHistoryFilters(): void {
    this.historyPartyFilter = SettlementHistoryPartyFilter.All;
    this.historyFromDate = '';
    this.historyToDate = '';
    this.historySearchTerm = '';
    this.historyPage = 1;
    this.loadHistory();
  }

  hasActiveHistoryFilters(): boolean {
    return this.historyPartyFilter !== SettlementHistoryPartyFilter.All ||
      !!this.historyFromDate ||
      !!this.historyToDate ||
      !!this.historySearchTerm.trim();
  }

  onHistoryPageChange(page: number): void {
    this.historyPage = page;
    this.loadHistory();
  }

  get historyTotalPages(): number {
    return Math.ceil(this.historyTotalRecords / this.historyPageSize) || 1;
  }

  openReceiptModal(content: TemplateRef<any>, item: SettlementHistoryItem): void {
    this.selectedReceipt = null;
    this.isLoadingReceipt = true;
    this.modalService.open(content, { size: 'lg', centered: true, scrollable: true });

    this.reconciliationService.getSettlementReceipt(item.id).subscribe({
      next: (receipt) => {
        this.selectedReceipt = receipt;
        this.isLoadingReceipt = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load settlement receipt', err);
        this.isLoadingReceipt = false;
        this.cdr.detectChanges();
      }
    });
  }

  printReceipt(): void {
    window.print();
  }

  printActiveHistory(): void {
    this.isPrintingHistory = true;
    const req: SettlementHistoryDataTableRequest = {
      page: 1,
      pageSize: 1000,
      searchTerm: this.historySearchTerm,
      partyFilter: this.historyPartyFilter,
      fromDate: this.historyFromDate || undefined,
      toDate: this.historyToDate || undefined,
      sortColumn: 'CompletedAt',
      sortDirection: 'DESC',
    };

    this.reconciliationService.getSettlementHistoryPrintData(req).subscribe({
      next: (items) => {
        this.historyPrintItems = items || [];
        this.isPrintingHistory = false;
        this.cdr.detectChanges();
        setTimeout(() => {
          window.print();
        }, 100);
      },
      error: (err) => {
        console.error('Failed to load print dataset', err);
        this.isPrintingHistory = false;
        this.cdr.detectChanges();
      }
    });
  }

  applyFilter(): void {
    if (!this.searchTerm.trim()) {
      this.filteredCaptains = [...this.captains];
      return;
    }
    const term = this.searchTerm.toLowerCase();
    this.filteredCaptains = this.captains.filter(
      (c) =>
        (c.captainName && c.captainName.toLowerCase().includes(term)) ||
        (c.phoneNumber && c.phoneNumber.includes(term)) ||
        c.captainUserId.toLowerCase().includes(term)
    );
  }

  get totalFloatInField(): number {
    return this.captains.reduce((sum, c) => sum + (c.cashFloatBalance || 0), 0);
  }

  get totalWagesEarned(): number {
    return this.captains.reduce((sum, c) => sum + (c.wagesEarnedBalance || 0), 0);
  }

  get totalNetDue(): number {
    return this.captains.reduce((sum, c) => sum + (c.expectedNetCashDue || 0), 0);
  }

  get activeFleetCount(): number {
    return this.captains.filter((c) => (c.cashFloatBalance || 0) > 0 || (c.expectedNetCashDue || 0) > 0).length;
  }

  get settleDiscrepancy(): number {
    if (!this.selectedCaptain) return 0;
    return (this.settleCashReceived || 0) - (this.selectedCaptain.expectedNetCashDue || 0);
  }

  openSettleModal(content: TemplateRef<any>, captain: CaptainSettlementSummary): void {
    this.selectedCaptain = captain;
    this.settleCashReceived = captain.expectedNetCashDue > 0 ? captain.expectedNetCashDue : 0;
    this.settleNotes = '';
    this.settleReason = '';
    this.settlementError = null;
    this.settlementSuccess = null;
    this.isSettling = false;

    this.modalService.open(content, { size: 'lg', backdrop: 'static', centered: true });
  }

  confirmSettlement(modal: any): void {
    if (!this.selectedCaptain) return;

    if (this.settleDiscrepancy !== 0 && !this.settleReason.trim()) {
      this.settlementError = 'Please provide a discrepancy reason for non-zero cash variance.';
      return;
    }

    this.isSettling = true;
    this.settlementError = null;

    const request: SettleCaptainShiftRequest = {
      captainUserId: this.selectedCaptain.captainUserId,
      physicalCashReceived: this.settleCashReceived,
      currency: this.selectedCaptain.currency || 'SYP',
      notes: this.settleNotes,
      discrepancyReason: this.settleReason,
    };

    this.reconciliationService.settleShift(request).subscribe({
      next: (result) => {
        this.settlementSuccess = result;
        this.isSettling = false;
        this.loadCaptains();
        this.loadHistory();
        this.cdr.detectChanges();
        setTimeout(() => {
          modal.close();
        }, 1500);
      },
      error: (err) => {
        this.isSettling = false;
        this.settlementError = err?.error?.message || err?.message || 'Settlement failed. Check server logs.';
        this.cdr.detectChanges();
      },
    });
  }

  openStatementModal(content: TemplateRef<any>, captain: CaptainSettlementSummary): void {
    this.selectedCaptain = captain;
    this.isLoadingStatement = true;
    this.statementDetails = null;

    this.modalService.open(content, { size: 'xl', centered: true });

    this.reconciliationService.getCaptainStatement(captain.captainUserId).subscribe({
      next: (data) => {
        this.statementDetails = data;
        this.isLoadingStatement = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load statement', err);
        this.isLoadingStatement = false;
        this.cdr.detectChanges();
      },
    });
  }

  formatPhoneNumber(phone?: string): string {
    if (!phone) return '-';
    let clean = phone.trim();
    if (!clean.startsWith('+')) {
      clean = '+' + clean;
    }
    // Syria: +963 912 345 666
    if (clean.startsWith('+963') && clean.length >= 12) {
      return `${clean.slice(0, 4)} ${clean.slice(4, 7)} ${clean.slice(7, 10)} ${clean.slice(10)}`;
    }
    // Turkey: +90 555 555 5553
    if (clean.startsWith('+90') && clean.length >= 12) {
      return `${clean.slice(0, 3)} ${clean.slice(3, 6)} ${clean.slice(6, 9)} ${clean.slice(9)}`;
    }
    // Universal 10-14 digit international chunking
    if (clean.length >= 11) {
      const countryCodeLen = clean.length > 12 ? 3 : 2;
      const cc = clean.slice(0, countryCodeLen + 1);
      const rest = clean.slice(countryCodeLen + 1);
      return `${cc} ${rest.slice(0, 3)} ${rest.slice(3, 6)} ${rest.slice(6)}`.trim();
    }
    return clean;
  }

  getInitials(name?: string): string {
    if (!name || !name.trim()) return 'M';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
    }
    return name.charAt(0).toUpperCase();
  }

  isSettled(cap: CaptainSettlementSummary): boolean {
    return (cap.cashFloatBalance || 0) === 0 && (cap.wagesEarnedBalance || 0) === 0 && (cap.expectedNetCashDue || 0) === 0;
  }

  printVoucher(batch: any): void {
    window.print();
  }

  printMerchantStatement(): void {
    window.print();
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }
}
