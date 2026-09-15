import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { HomeCategoriesListComponent } from './components/home-categories-list/home-categories-list.component';

@NgModule({
  declarations: [HomeCategoriesListComponent],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule,
    NgbModalModule,
    TranslateModule,
    RouterModule.forChild([
      {
        path: '',
        component: HomeCategoriesListComponent,
      },
    ]),
  ],
})
export class HomeCategoriesModule {}
