import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { PopularProductsListComponent } from './components/popular-products-list/popular-products-list.component';

const routes: Routes = [
  {
    path: '',
    component: PopularProductsListComponent,
  },
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class PopularProductsRoutingModule {}
