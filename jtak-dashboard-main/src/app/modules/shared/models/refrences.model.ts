import { Brand } from 'src/app/pages/brands/models/brand.model';
import { Category } from 'src/app/pages/categories/models/Category.model';
import { Color } from 'src/app/pages/colors/models/color.model';

export interface References {
  brands: Brand[];
  categories: Category[];
  colors: Color[];
}