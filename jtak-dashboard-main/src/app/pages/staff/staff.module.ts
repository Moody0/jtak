import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { NgbModule } from '@ng-bootstrap/ng-bootstrap';
import { StaffComponent } from './staff.component';
@NgModule({ declarations: [StaffComponent], imports: [CommonModule, FormsModule, ReactiveFormsModule, NgbModule, RouterModule.forChild([{ path: '', component: StaffComponent }])] })
export class StaffModule {}
