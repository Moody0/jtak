import { PaginatorState } from './paginator.model';
import { SortState } from './sort.model';

export interface ITableState {
  filter: {};
  paginator: PaginatorState;
  sorting: SortState;
  searchTerm: string;
}

export interface TableResponseModel<T> {
  items: T[];
  totalRecords: number;
}

export interface ICreateAction {
  create(): void;
}

export interface IEditAction {
  edit(id: number): void;
}

export interface IDeleteAction {
  delete(id: number, extraData: any): void;
}

export interface IDeleteSelectedAction {
  ngOnInit(): void;
  deleteSelected(): void;
}

export interface IFetchSelectedAction {
  ngOnInit(): void;
  fetchSelected(): void;
}

export interface IUpdateStatusForSelectedAction {
  ngOnInit(): void;
  updateStatusForSelected(): void;
}
