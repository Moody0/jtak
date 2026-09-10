//export interface AuthModel {
//  userID: string;
//  token: string;
//  expiration: string;
//  userName: string;
//  displayName: string;
//}
export interface AuthModel {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token: string;
  createDate: Date;
}
