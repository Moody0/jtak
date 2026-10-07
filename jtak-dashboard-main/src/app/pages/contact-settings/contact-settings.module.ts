import { DashboardWriteDirective } from 'src/app/modules/shared/directives/dashboard-write.directive';
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { NgbModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslationModule } from 'src/app/modules/i18n';
import { ContactSettingsComponent } from './contact-settings.component';

@NgModule({
  declarations: [ContactSettingsComponent],
  imports: [DashboardWriteDirective, 
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    NgbModule,
    TranslationModule,
    RouterModule.forChild([
      {
        path: '',
        component: ContactSettingsComponent,
      },
    ]),
  ],
})
export class ContactSettingsModule {}
