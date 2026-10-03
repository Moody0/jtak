import { Component, OnInit, Input, OnDestroy, ChangeDetectorRef } from '@angular/core';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { SubSink } from 'subsink';
import { interval, Subscription } from 'rxjs';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
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
  errorMessage = '';
  private telemetryRequest?: Subscription;
  private destroyed = false;
  private liveVersion = 0;
  private fallbackUrl = '';
  private safeFallbackUrl: SafeResourceUrl | null = null;
  private validCoordinates(lat: any, lng: any): boolean {
    return typeof lat === 'number' && typeof lng === 'number' && Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180;
  }

  // Map settings
  mapCenter: google.maps.LatLngLiteral = { lat: 34.7324, lng: 36.7137 };
  get hasGoogleMaps(): boolean {
    return typeof window !== 'undefined' && !!(window as any).google?.maps &&
      !document.querySelector('script[src*="YOUR_GOOGLE_MAPS_BROWSER_KEY"]');
  }
  get fallbackMapUrl(): SafeResourceUrl | null {
    if (!this.sanitizer) return null;
    const { lat, lng } = this.mapCenter;
    const radius = 0.018;
    const url = 'https://www.openstreetmap.org/export/embed.html?bbox=' +
      [lng - radius, lat - radius, lng + radius, lat + radius].join(',') + '&layer=mapnik&marker=' + lat + ',' + lng;
    if (url !== this.fallbackUrl) {
      this.fallbackUrl = url;
      this.safeFallbackUrl = this.sanitizer.bypassSecurityTrustResourceUrl(url);
    }
    return this.safeFallbackUrl;
  }
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
    private cdr: ChangeDetectorRef,
    private sanitizer?: DomSanitizer
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
        if (this.validCoordinates(lat, lng)) {
          this.liveVersion++;
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
          this.mapCenter = { lat: lat!, lng: lng! };
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
    } else { this.isLoading = false; }
  }

  fetchTelemetry(): void {
    if (!this.order?.id || this.destroyed || (this.telemetryRequest && !this.telemetryRequest.closed)) return;
    const initialLiveVersion = this.liveVersion;
    this.telemetryRequest = this.ordersService.getLiveTrack(this.order.id).subscribe({
      next: (data) => {
        this.errorMessage = '';
        if (this.liveTrack && initialLiveVersion !== this.liveVersion) {
          data = { ...data, driverLat: this.liveTrack.driverLat, driverLng: this.liveTrack.driverLng,
            driverName: this.liveTrack.driverName, driverPhoneNumber: this.liveTrack.driverPhoneNumber, isLive: this.liveTrack.isLive };
        }
        this.liveTrack = data;
        this.isLoading = false;
        this.lastUpdated = new Date();
        if (this.validCoordinates(data.driverLat, data.driverLng)) {
          this.mapCenter = { lat: data.driverLat!, lng: data.driverLng! };
        } else if (this.validCoordinates(data.destinationLat, data.destinationLng)) {
          this.mapCenter = { lat: data.destinationLat, lng: data.destinationLng };
        }
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoading = false;
        this.errorMessage = 'تعذر تحديث التتبع. حاول مرة أخرى.';
        this.cdr.detectChanges();
      }
    });
  }

  getDriverMarker(): google.maps.LatLngLiteral | null {
    if (this.validCoordinates(this.liveTrack?.driverLat, this.liveTrack?.driverLng)) {
      return { lat: this.liveTrack!.driverLat!, lng: this.liveTrack!.driverLng! };
    }
    return null;
  }

  getDestinationMarker(): google.maps.LatLngLiteral | null {
    if (this.validCoordinates(this.liveTrack?.destinationLat, this.liveTrack?.destinationLng)) {
      return { lat: this.liveTrack!.destinationLat, lng: this.liveTrack!.destinationLng };
    }
    if (this.validCoordinates(this.order?.lat, this.order?.lng)) {
      return { lat: this.order.lat, lng: this.order.lng };
    }
    return null;
  }

  getGoogleMapsUrl(): string {
    if (this.validCoordinates(this.liveTrack?.driverLat, this.liveTrack?.driverLng)) {
      return `https://www.google.com/maps/search/?api=1&query=${this.liveTrack!.driverLat},${this.liveTrack!.driverLng}`;
    }
    if (this.validCoordinates(this.order?.lat, this.order?.lng)) {
      return `https://www.google.com/maps/search/?api=1&query=${this.order.lat},${this.order.lng}`;
    }
    return 'https://maps.google.com';
  }

  ngOnDestroy(): void {
    this.destroyed = true;
    this.telemetryRequest?.unsubscribe();
    if (this.order?.id) {
      this.signalrService.untrackOrder(this.order.id);
    }
    this.subs.unsubscribe();
  }
}
