// tslint:disable:variable-name
import { HttpClient, HttpParams, HttpHeaders } from '@angular/common/http';
import { BehaviorSubject, Observable, Subscription, of } from 'rxjs';
import { finalize, tap, map, take, catchError } from 'rxjs/operators';
import { PaginatorState } from '../models/paginator.model';
import { ITableState, TableResponseModel } from '../models/table.model';
import { BaseModel } from '../models/base.model';
import { SortState } from '../models/sort.model';
import { RequestTypes } from '../models/request-types.enum';

const DEFAULT_STATE: ITableState = {
  filter: {},
  paginator: new PaginatorState(),
  sorting: new SortState(),
  searchTerm: '',
};

export abstract class TableService<T> {
  // Private fields
  private _items$ = new BehaviorSubject<T[]>([]);
  private _item$ = new BehaviorSubject<any>(null);
  private _totalRecords$ = new BehaviorSubject<number>(0);
  public _isLoading$ = new BehaviorSubject<boolean>(false);
  public _isFirstLoading$ = new BehaviorSubject<boolean>(false);
  public _isRequestLoading$ = new BehaviorSubject<boolean>(false);
  private _tableState$ = new BehaviorSubject<ITableState>(DEFAULT_STATE);
  private _subscriptions: Subscription[] = [];

  // Getters
  get items$() {
    return this._items$.asObservable();
  }

  get item$() {
    return this._item$.asObservable();
  }

  get totalRecords$() {
    return this._totalRecords$.asObservable();
  }
  get isLoading$() {
    return this._isLoading$.asObservable();
  }
  get isFirstLoading$() {
    return this._isFirstLoading$.asObservable();
  }

  get isRequestLoading$() {
    return this._isRequestLoading$.asObservable();
  }

  get subscriptions() {
    return this._subscriptions;
  }
  // State getters
  get paginator() {
    return this._tableState$.value.paginator;
  }
  get filter() {
    return this._tableState$.value.filter;
  }
  get sorting() {
    return this._tableState$.value.sorting;
  }
  get searchTerm() {
    return this._tableState$.value.searchTerm;
  }

  protected http: HttpClient;

  httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json',
    }),
  };

  // API URL has to be overrided
  BASE_URL = '';
  GET_ALL_URL = '';
  GET_ONE_URL = '';
  CREATE_URL = '';
  UPDATE_URL = '';
  DELETE_URL = '';
  DEFAULT_SORT_FIELD = '';

  constructor(http: HttpClient) {
    this.http = http;
  }

  public fetch(queryParams: any = null) {
    let params = new HttpParams();

    if (queryParams) {
      Object.entries(queryParams).forEach((item: any) => {
        params = params.append(item[0], item[1]);
      });
    }

    if (this.filter) {
      Object.entries(this.filter).forEach((item: any) => {
        params = params.append(item[0], item[1]);
      });
    }

    params = params.append('pageSize', this.paginator.pageSize.toString());
    params = params.append('pageNumber', this.paginator.page.toString());
    params = params.append('sortField', this.sorting.column);
    params = params.append('sortOrder', this.sorting.direction);

    if (this.searchTerm) {
      params = params.append('search', this.searchTerm);
    }

    const url = `${this.BASE_URL}/${this.GET_ALL_URL}`;
    this._isLoading$.next(true);

    // Prune closed subscriptions to eliminate memory leaks
    this._subscriptions = this._subscriptions.filter(s => !s.closed);

    const request = this.http
      .get<TableResponseModel<T>>(url, { params })
      .pipe(
        take(1),
        tap((res: TableResponseModel<T>) => {
          this._items$.next(res.items);
          this._totalRecords$.next(res.totalRecords);
          this.patchStateWithoutFetch({
            paginator: this._tableState$.value.paginator.recalculatePaginator(
              res.totalRecords
            ),
          });
        }),
        catchError(() => {
          this._isLoading$.next(false);
          return of({ items: [], totalRecords: 0 } as TableResponseModel<T>);
        }),
        finalize(() => {
          this._isLoading$.next(false);
        })
      )
      .subscribe(() => {
        this._subscriptions = this._subscriptions.filter(s => !s.closed);
      });
    this._subscriptions.push(request);
  }

  public fetchPost(queryParams: any = null) {
    let params = new HttpParams();

    if (queryParams) {
      Object.entries(queryParams).forEach((item: any) => {
        params = params.append(item[0], item[1]);
      });
    }

    if (this.filter) {
      Object.entries(this.filter).forEach((item: any) => {
        params = params.append(item[0], item[1]);
      });
    }

    const body: any = {
      pageSize: this.paginator.pageSize,
      pageNumber: this.paginator.page,
      sortField: this.sorting.column,
      sortOrder: this.sorting.direction,
    };

    if (this.searchTerm) {
      body.search = this.searchTerm;
    }

    const url = `${this.BASE_URL}/${this.GET_ALL_URL}`;
    this._isLoading$.next(true);

    // Prune closed subscriptions to eliminate memory leaks
    this._subscriptions = this._subscriptions.filter(s => !s.closed);

    const request = this.http
      .post<TableResponseModel<T>>(url, body,  { params: params })
      .pipe(
        take(1),
        tap((res: TableResponseModel<T>) => {
          this._items$.next(res.items);
          this._totalRecords$.next(res.totalRecords);
          this.patchStateWithoutFetch({
            paginator: this._tableState$.value.paginator.recalculatePaginator(
              res.totalRecords
            ),
          });
        }),
        catchError(() => {
          this._isLoading$.next(false);
          return of({ items: [], totalRecords: 0 } as TableResponseModel<T>);
        }),
        finalize(() => {
          this._isLoading$.next(false);
        })
      )
      .subscribe(() => {
        this._subscriptions = this._subscriptions.filter(s => !s.closed);
      });
    this._subscriptions.push(request);
  }

  // CREATE
  // server should return the object with ID
  create(item: BaseModel): Observable<string> {
    const url = `${this.BASE_URL}/${this.CREATE_URL}`;
    this._isLoading$.next(true);
    return this.http
      .post<string>(url, item, this.httpOptions)
      .pipe(finalize(() => this._isLoading$.next(false)));
  }

  getItem(id: string | number): Observable<BaseModel> {
    this._isFirstLoading$.next(true);
    const url = `${this.BASE_URL}/${this.GET_ONE_URL}/${id}`;
    return this.http.get<BaseModel>(url).pipe(
      map((res: any) => {
        return res;
      }),
      finalize(() => this._isFirstLoading$.next(false))
    );
  }

  // UPDATE
  update(item: BaseModel): Observable<boolean> {
    const url = `${this.BASE_URL}/${this.UPDATE_URL}/${item.id}`;
    this._isLoading$.next(true);
    return this.http
      .put<boolean>(url, item, this.httpOptions)
      .pipe(finalize(() => this._isLoading$.next(false)));
  }

  // DELETE
  delete(id: any): Observable<any> {
    this._isLoading$.next(true);
    const url = `${this.BASE_URL}/${this.DELETE_URL}/${id}`;
    return this.http
      .delete(url)
      .pipe(finalize(() => this._isLoading$.next(false)));
  }

  request(
    url: string,
    requestType: RequestTypes = RequestTypes.GET,
    data: any = null
  ): Observable<any> {
    this._isRequestLoading$.next(true);
    return this.http[requestType](
      url,
      RequestTypes.GET ? this.httpOptions : data
    ).pipe(finalize(() => this._isRequestLoading$.next(false)));
  }

  public setDefaults() {
    this.patchStateWithoutFetch({ filter: {} });
    this.patchStateWithoutFetch({
      sorting: new SortState(this.DEFAULT_SORT_FIELD || ''),
    });
    this.patchStateWithoutFetch({ searchTerm: '' });
    this.patchStateWithoutFetch({
      paginator: new PaginatorState(),
    });
    this._isFirstLoading$.next(true);
    this._isLoading$.next(true);
    this._tableState$.next(DEFAULT_STATE);
  }

  // Base Methods
  public patchState(
    patch: Partial<ITableState>,
    queryParams = null,
    fetchWithPost = true
  ) {
    this.patchStateWithoutFetch(patch);
    if (fetchWithPost) {
      this.fetchPost(queryParams);
    } else {
      this.fetch(queryParams);
    }
  }

  public patchStateWithoutFetch(patch: Partial<ITableState>) {
    const newState = Object.assign(this._tableState$.value, patch);
    this._tableState$.next(newState);
  }

  public extractQueryParams(obj: any) {
    let params: any = {};
    Object.entries(obj).forEach((item: any) => {
      if (item[1]) {
        params[item[0]] = item[1];
      }
    });

    return params;
  }
}
