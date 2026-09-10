import { BaseModel } from 'src/app/_metronic/shared/crud-table';

export interface Page extends BaseModel {
    Title: string;
    seoDescription: string;
    seoKeywords: string;
    seoKeywordsArr: string[];
    seoFeaturedImage: string;
  
    subTitle: string;
    headerImage: string;
    mobileHeaderImage: string;
    body: string;
  }