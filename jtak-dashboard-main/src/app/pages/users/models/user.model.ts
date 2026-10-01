import { BaseModel } from 'src/app/_metronic/shared/crud-table';
import { AppRoleName } from '../enums/role.enum';

export enum CaptainCompensationType {
  SalariedEmployee = 0,
  PerKilometer = 1,
  Percentage = 2,
}

export interface User extends BaseModel {
  email: string;
  phoneNumber: string;
  firstName: string;
  lastName: string;
  fullName: string;
  isActive: boolean;
  profilePhoto?: string;
  role: AppRoleName;
  lang: string;
  countryPhoneCode: string;
  password?: string;
  maxCashFloat?: number;
  captainCompensationType?: CaptainCompensationType;
  captainRate?: number;
}
export interface Balance extends BaseModel {
  name: string;
  amount: number;
  CreatedDate: string;
}
