import { UntypedFormGroup } from '@angular/forms';

export interface ISearchView {
  searchGroup: UntypedFormGroup;
  ngOnInit(): void;
  searchForm(): void;
  search(searchTerm: string): void;
}
