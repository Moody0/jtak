import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModalModule } from '@ng-bootstrap/ng-bootstrap';
import { SharedModule } from 'src/app/modules/shared/shared.module';
import { NgSelectModule } from '@ng-select/ng-select';
import { PageComponent } from './components/page/page.component';
import { NgxEditorModule } from 'ngx-editor';

@NgModule({
  declarations: [
    PageComponent
  ],
  imports: [
    CommonModule,
    SharedModule,
    FormsModule,
    ReactiveFormsModule,
    NgxEditorModule,
    RouterModule.forChild([
      {
        path: ':id',
        component: PageComponent,
      }
    ]),
    FormsModule,
    NgSelectModule,
    NgbModalModule,
  ],
})
export class PagesModule {}
