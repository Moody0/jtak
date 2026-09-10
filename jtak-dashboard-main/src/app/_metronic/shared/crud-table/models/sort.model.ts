export type SortDirection = 'ASC' | 'DESC' | '';

export interface ISortState {
  column: string;
  direction: SortDirection;
}

export class SortState implements ISortState {
  column = 'id'; // Id by default
  direction: SortDirection = 'DESC'; // asc by default;

  constructor(column?: string, direction?: SortDirection) {
    if (column) {
      this.column = column;
    }

    if (direction) {
      this.direction = direction;
    }
  }
}

export interface ISortView {
  sorting: SortState;
  ngOnInit(): void;
  sort(column: string): void;
}
