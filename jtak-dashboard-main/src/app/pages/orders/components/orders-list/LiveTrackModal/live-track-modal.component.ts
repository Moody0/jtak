import { Component, OnInit, Input, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { interval } from 'rxjs';
import { OrdersService } from '../../../services/orders.service';
import { Order, OrderLiveTrack } from '../../../models/orders.model';
import { SignalrTrackingService, LocationTelemetry } from '../../../services/signalr-tracking.service';

@Component({
  selector: 'app-live-track-modal',
  templateUrl: './live-track-modal.component.html',
  styleUrls: ['./live-track-modal.component.scss']
})
export class LiveTrackModalComponent implements OnInit, OnDestroy {
  private subs = new SubSink();
  @Input() order: Order;

  liveTrack: OrderLiveTrack | null = null;
  isLoading = true;
  lastUpdated: Date = new Date();
  isLiveConnected = false;

  // Map settings
  mapCenter: google.maps.LatLngLiteral = { lat: 33.5138, lng: 36.2765 };
  mapZoom = 14;
  mapOptions: google.maps.MapOptions = {
    disableDefaultUI: false,
    zoomControl: true,
    mapTypeControl: false,
    streetViewControl: false,
    fullscreenControl: true
  };

  constructor(
    public modal: NgbActiveModal,
    private ordersService: OrdersService,
    private signalrService: SignalrTrackingService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    if (this.order?.id) {
      // 1. Initial snapshot via HTTP
      this.fetchTelemetry();

      // 2. Real-time telemetry via SignalR
      this.signalrService.trackOrder(this.order.id);

      this.subs.sink = this.signalrService.locationUpdated$.subscribe((telemetry: LocationTelemetry) => {
        if (!telemetry || (telemetry.orderId && telemetry.orderId !== this.order.id)) return;
        const lat = telemetry.driverLat ?? telemetry.lat;
        const lng = telemetry.driverLng ?? telemetry.lng;
        if (lat && lng) {
          if (!this.liveTrack) {
            this.liveTrack = {
              orderId: this.order.id,
              orderStatus: 2,
              driverName: telemetry.driverName || this.order.deliveryUser,
              driverPhoneNumber: telemetry.driverPhone,
              driverLat: lat,
              driverLng: lng,
              destinationLat: this.order.lat,
              destinationLng: this.order.lng,
              destinationAddress: this.order.address,
              isLive: true,
              etaMinutes: 0,
              remainingDistanceMeters: 0,
              currentStopIndex: 0,
              currentStopIsDarkStore: false,
              stops: []
            };
          } else {
            this.liveTrack.driverLat = lat;
            this.liveTrack.driverLng = lng;
            this.liveTrack.isLive = true;
            if (telemetry.driverName) this.liveTrack.driverName = telemetry.driverName;
            if (telemetry.driverPhone) this.liveTrack.driverPhoneNumber = telemetry.driverPhone;
          }
          this.mapCenter = { lat, lng };
          this.lastUpdated = new Date();
          this.isLoading = false;
          this.isLiveConnected = true;
          this.cdr.detectChanges();
        }
      });

      this.subs.sink = this.signalrService.connectionState$.subscribe(state => {
        this.isLiveConnected = state === 'connected';
        this.cdr.detectChanges();
      });

      // 3. Fallback poll at relaxed 15s interval in case of WebSocket interruption
      this.subs.sink = interval(15000).subscribe(() => this.fetchTelemetry());
    }
  }

  fetchTelemetry(): void {
    if (!this.order?.id) return;
    this.ordersService.getLiveTrack(this.order.id).subscribe({
      next: (data) => {
        this.liveTrack = data;
        this.isLoading = false;
        this.lastUpdated = new Date();
        if (data.driverLat && data.driverLng) {
          this.mapCenter = { lat: data.driverLat, lng: data.driverLng };
        } else if (data.destinationLat && data.destinationLng) {
          this.mapCenter = { lat: data.destinationLat, lng: data.destinationLng };
        }
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoading = false;
        this.cdr.detectChanges();
      }
    });
  }

  getDriverMarker(): google.maps.LatLngLiteral | null {
    if (this.liveTrack?.driverLat && this.liveTrack?.driverLng) {
      return { lat: this.liveTrack.driverLat, lng: this.liveTrack.driverLng };
    }
    return null;
  }

  getDestinationMarker(): google.maps.LatLngLiteral | null {
    if (this.liveTrack?.destinationLat && this.liveTrack?.destinationLng) {
      return { lat: this.liveTrack.destinationLat, lng: this.liveTrack.destinationLng };
    }
    if (this.order?.lat && this.order?.lng) {
      return { lat: this.order.lat, lng: this.order.lng };
    }
    return null;
  }

  getGoogleMapsUrl(): string {
    if (this.liveTrack?.driverLat && this.liveTrack?.driverLng) {
      return `https://www.google.com/maps/search/?api=1&query=${this.liveTrack.driverLat},${this.liveTrack.driverLng}`;
    }
    if (this.order?.lat && this.order?.lng) {
      return `https://www.google.com/maps/search/?api=1&query=${this.order.lat},${this.order.lng}`;
    }
    return 'https://maps.google.com';
  }

  ngOnDestroy(): void {
    if (this.order?.id) {
      this.signalrService.untrackOrder(this.order.id);
    }
    this.subs.unsubscribe();
  }
}
