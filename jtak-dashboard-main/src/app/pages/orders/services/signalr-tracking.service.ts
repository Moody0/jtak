import { Injectable, OnDestroy, PLATFORM_ID, Inject } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import * as signalR from '@microsoft/signalr';
import { BehaviorSubject, Subject, Observable } from 'rxjs';
import { environment } from 'src/environments/environment';
import { AuthService } from 'src/app/modules/auth';

export interface LocationTelemetry {
  orderId?: number;
  driverId?: string;
  driverName?: string;
  driverPhone?: string;
  driverLat?: number;
  driverLng?: number;
  lat?: number;
  lng?: number;
  speed?: number;
  heading?: number;
  timestamp?: string;
}

export type SignalRConnectionState = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

@Injectable({
  providedIn: 'root'
})
export class SignalrTrackingService implements OnDestroy {
  private hubConnection: signalR.HubConnection | null = null;
  private connectionStateSubject = new BehaviorSubject<SignalRConnectionState>('disconnected');
  private locationUpdatedSubject = new Subject<LocationTelemetry>();
  private radarUpdatedSubject = new Subject<any>();
  private orderDeliveredSubject = new Subject<any>();
  private driverAssignedSubject = new Subject<any>();

  public connectionState$ = this.connectionStateSubject.asObservable();
  public locationUpdated$ = this.locationUpdatedSubject.asObservable();
  public radarUpdated$ = this.radarUpdatedSubject.asObservable();
  public orderDelivered$ = this.orderDeliveredSubject.asObservable();
  public driverAssigned$ = this.driverAssignedSubject.asObservable();

  private activeOrderIds = new Set<number>();
  private isRadarJoined = false;

  constructor(
    private authService: AuthService,
    @Inject(PLATFORM_ID) private platformId: any
  ) {}

  public async startConnection(): Promise<void> {
    if (!isPlatformBrowser(this.platformId)) return;
    if (this.hubConnection && this.hubConnection.state === signalR.HubConnectionState.Connected) {
      return;
    }

    const hubUrl = `${environment.baseUrl}/hubs/tracking`;

    this.hubConnection = new signalR.HubConnectionBuilder()
      .withUrl(hubUrl, {
        accessTokenFactory: () => {
          const auth = this.authService.getAuthFromSessionStorage() || this.authService.getAuthFromLocalStorage();
          return auth?.access_token || '';
        },
        skipNegotiation: false,
        transport: signalR.HttpTransportType.WebSockets | signalR.HttpTransportType.LongPolling
      })
      .withAutomaticReconnect([0, 2000, 5000, 10000, 30000])
      .configureLogging(environment.production ? signalR.LogLevel.None : signalR.LogLevel.Warning)
      .build();

    this.registerEventHandlers();

    try {
      this.connectionStateSubject.next('connecting');
      await this.hubConnection.start();
      this.connectionStateSubject.next('connected');

      // Re-join active groups if reconnected
      for (const orderId of this.activeOrderIds) {
        await this.hubConnection.invoke('JoinOrderTracking', orderId);
      }
      if (this.isRadarJoined) {
        await this.hubConnection.invoke('JoinFleetRadar');
      }
    } catch {
      this.connectionStateSubject.next('disconnected');
    }
  }

  private registerEventHandlers(): void {
    if (!this.hubConnection) return;

    this.hubConnection.onreconnecting(() => {
      this.connectionStateSubject.next('reconnecting');
    });

    this.hubConnection.onreconnected(async () => {
      this.connectionStateSubject.next('connected');
      for (const orderId of this.activeOrderIds) {
        try {
          await this.hubConnection?.invoke('JoinOrderTracking', orderId);
        } catch {}
      }
      if (this.isRadarJoined) {
        try {
          await this.hubConnection?.invoke('JoinFleetRadar');
        } catch {}
      }
    });

    this.hubConnection.onclose(() => {
      this.connectionStateSubject.next('disconnected');
    });

    this.hubConnection.on('OnLocationUpdated', (data: any) => {
      this.locationUpdatedSubject.next(data);
    });

    this.hubConnection.on('OnCourierLocationUpdated', (data: any) => {
      this.radarUpdatedSubject.next(data);
    });

    this.hubConnection.on('OnFleetLocationUpdated', (data: any) => {
      this.radarUpdatedSubject.next(data);
    });

    this.hubConnection.on('OnDriverAssigned', (data: any) => {
      this.driverAssignedSubject.next(data);
    });

    this.hubConnection.on('OnOrderDelivered', (data: any) => {
      this.orderDeliveredSubject.next(data);
    });
  }

  public async trackOrder(orderId: number): Promise<void> {
    this.activeOrderIds.add(orderId);
    if (!this.hubConnection || this.hubConnection.state !== signalR.HubConnectionState.Connected) {
      await this.startConnection();
    }
    if (this.hubConnection && this.hubConnection.state === signalR.HubConnectionState.Connected) {
      try {
        await this.hubConnection.invoke('JoinOrderTracking', orderId);
      } catch {}
    }
  }

  public async untrackOrder(orderId: number): Promise<void> {
    this.activeOrderIds.delete(orderId);
    if (this.hubConnection && this.hubConnection.state === signalR.HubConnectionState.Connected) {
      try {
        await this.hubConnection.invoke('LeaveOrderTracking', orderId);
      } catch {}
    }
  }

  public async joinRadar(): Promise<void> {
    this.isRadarJoined = true;
    if (!this.hubConnection || this.hubConnection.state !== signalR.HubConnectionState.Connected) {
      await this.startConnection();
    }
    if (this.hubConnection && this.hubConnection.state === signalR.HubConnectionState.Connected) {
      try {
        await this.hubConnection.invoke('JoinCourierRadar');
      } catch {
        try {
          await this.hubConnection.invoke('JoinFleetRadar');
        } catch {}
      }
    }
  }

  public async leaveRadar(): Promise<void> {
    this.isRadarJoined = false;
    if (this.hubConnection && this.hubConnection.state === signalR.HubConnectionState.Connected) {
      try {
        await this.hubConnection.invoke('LeaveCourierRadar');
      } catch {
        try {
          await this.hubConnection.invoke('LeaveFleetRadar');
        } catch {}
      }
    }
  }

  public async stopConnection(): Promise<void> {
    if (this.hubConnection) {
      try {
        await this.hubConnection.stop();
      } catch {}
      this.hubConnection = null;
      this.connectionStateSubject.next('disconnected');
    }
  }

  ngOnDestroy(): void {
    this.stopConnection();
  }
}
