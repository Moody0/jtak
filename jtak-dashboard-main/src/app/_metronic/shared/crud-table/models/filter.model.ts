import { UntypedFormGroup } from '@angular/forms';

export interface IFilterView {
  filterGroup: UntypedFormGroup;
  ngOnInit(): void;
  filterForm(): void;
  filter(): void;
}
