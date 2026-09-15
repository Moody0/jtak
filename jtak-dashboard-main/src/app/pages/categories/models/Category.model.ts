import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Category extends BaseModel {
  title: string;
  active: boolean;
  parentId: number | null;
  icon?: string;
  parent?: string;
  order?: number;
  parentTitle?: string;
  subCategoriesCount?: number;
  fullPath?: string;
}
