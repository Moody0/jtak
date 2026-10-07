export interface UserModel {
  dashboardAccess?: import('./dashboard-access.model').DashboardAccess;
  id: string;
  firstName: string;
  lastName: string;
  fullName: string;
  profilePhoto: string;
  phoneNumber: string;
  email: string;
  oldPassword: string;
  password: string;
  isActive: boolean;
  userType: number;
  claims: number[];
}
