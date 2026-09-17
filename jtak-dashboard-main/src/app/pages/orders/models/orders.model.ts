import { BaseModel } from 'src/app/_metronic/shared/crud-table';
import { OrdersDetails as OrdersDetail } from './ordersDetails.model';

export interface Order extends BaseModel {
    id: number;
    user: string;
    userId: string;
    deliveryId: string;
    deliveryUser: string;
    purchaseDate: string;
    address: string;
    description: string;
    phonenumber: string;
    lat: number;
    lng: number;
    price: number;
    orderDetails: OrdersDetail[];
    createdDate: string;
    paymentMethod: number;
    deliveryOtp?: string;
    deliveredAt?: string;
    isJtakMarketOrder?: boolean;
    requiresMerchantDecision?: boolean;
    canAdminApprove?: boolean;
    canAdminMarkReady?: boolean;
    adminFlowMessage?: string;
    notes?: string;
    warning?: string;
}

export interface ShippingStopProgress {
    index: number;
    title: string;
    isDarkStore: boolean;
    isCompleted: boolean;
    lat: number;
    lng: number;
    stopType: number;
}

export interface OrderLiveTrack {
    orderId: number;
    orderStatus: number;
    driverId?: string;
    driverName?: string;
    driverPhoneNumber?: string;
    driverLat?: number;
    driverLng?: number;
    heading?: number;
    speed?: number;
    locationUpdatedAt?: string;
    isLive: boolean;
    etaMinutes: number;
    remainingDistanceMeters: number;
    destinationLat: number;
    destinationLng: number;
    destinationAddress?: string;
    currentStopIndex: number;
    currentStopTitle?: string;
    currentStopIsDarkStore: boolean;
    stops: ShippingStopProgress[];
}

export interface OrderStatusHistoryItem {
    id: number;
    orderId: number;
    status: number;
    statusName: string;
    statusArabic: string;
    createdDate: string;
    createdBy: string;
    driverId?: string;
    driverName?: string;
    details?: string;
}

