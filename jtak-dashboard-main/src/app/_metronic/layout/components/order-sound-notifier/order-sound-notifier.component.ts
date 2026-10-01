import { Component, OnInit, OnDestroy, Inject, PLATFORM_ID } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Subscription, timer, of } from 'rxjs';
import { catchError, filter, switchMap } from 'rxjs/operators';
import { environment } from 'src/environments/environment';
import { AuthService } from 'src/app/modules/auth';
import { NotificationSummaryService } from '../../core/notification-summary.service';

export interface NewOrderItem {
  id: number;
  order_number: string;
  total_amount: number;
  recipient_name?: string;
  status?: string;
  created_at?: string;
  visible?: boolean;
}

export interface LatestOrdersResponse {
  latest_id: number;
  new_orders: NewOrderItem[];
  count: number;
  pending_orders_count?: number;
}

@Component({
  selector: 'app-order-sound-notifier',
  templateUrl: './order-sound-notifier.component.html',
  styleUrls: ['./order-sound-notifier.component.scss']
})
export class OrderSoundNotifierComponent implements OnInit, OnDestroy {
  public lastSeenId = 0;
  public isPolling = false;
  public recentNewOrders: NewOrderItem[] = [];
  public audioUnlocked = false;

  private pollSub: Subscription | null = null;
  private readonly pollIntervalMs = 7500; // 7.5 seconds - matches best-market
  private originalTitle = '';
  private titleInterval: any = null;
  private audioContext: any = null;
  private unlockHandler: any = null;
  private focusHandler: any = null;
  private testSoundHandler: any = null;

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private notificationSummaryService: NotificationSummaryService,
    private router: Router,
    @Inject(PLATFORM_ID) private platformId: any
  ) {}

  ngOnInit(): void {
    if (!isPlatformBrowser(this.platformId)) return;

    this.originalTitle = document.title;

    if (localStorage.getItem('admin_order_sound_muted') === null) {
      localStorage.setItem('admin_order_sound_muted', 'false');
    }

    this.initUserGestureAudioUnlock();

    this.focusHandler = () => {
      this.stopTitleBlink();
    };
    window.addEventListener('focus', this.focusHandler);

    this.testSoundHandler = () => {
      this.playOrderSound(true);
    };
    window.addEventListener('order-sound:play-test', this.testSoundHandler);

    this.startPolling();
  }

  private initUserGestureAudioUnlock(): void {
    this.unlockHandler = () => {
      this.unlockAudio();
      window.removeEventListener('click', this.unlockHandler);
      window.removeEventListener('keydown', this.unlockHandler);
      window.removeEventListener('touchstart', this.unlockHandler);
    };
    window.addEventListener('click', this.unlockHandler, { once: true });
    window.addEventListener('keydown', this.unlockHandler, { once: true });
    window.addEventListener('touchstart', this.unlockHandler, { once: true });
  }

  public unlockAudio(): void {
    try {
      const AudioCtx = (window as any).AudioContext || (window as any).webkitAudioContext;
      if (AudioCtx) {
        if (!this.audioContext) {
          this.audioContext = new AudioCtx();
        }
        if (this.audioContext.state === 'suspended') {
          this.audioContext.resume();
        }
      }
      this.audioUnlocked = true;
    } catch {}
  }

  private startPolling(): void {
    if (this.pollSub) return;

    this.pollSub = timer(1000, this.pollIntervalMs)
      .pipe(
        filter(() => !!(this.authService.getAuthFromSessionStorage() || this.authService.getAuthFromLocalStorage())),
        switchMap(() => this.checkOrdersObservable())
      )
      .subscribe();
  }

  private checkOrdersObservable() {
    if (this.isPolling) return of(null);
    this.isPolling = true;

    const isInitial = this.lastSeenId === 0;
    const url = `${environment.apiUrl}/Admin/Orders/Latest?since_id=${this.lastSeenId}&_t=${Date.now()}`;

    return this.http.get<LatestOrdersResponse>(url).pipe(
      catchError(() => of(null)),
      switchMap((res) => {
        this.isPolling = false;
        if (!res) return of(null);

        if (isInitial) {
          this.lastSeenId = res.latest_id || 0;
        } else {
          if (res.count > 0 && res.new_orders && res.new_orders.length > 0) {
            this.lastSeenId = res.latest_id;
            this.handleNewOrdersReceived(res.new_orders);
          } else if (res.latest_id > this.lastSeenId) {
            this.lastSeenId = res.latest_id;
          }
        }
        return of(res);
      })
    );
  }

  private handleNewOrdersReceived(orders: NewOrderItem[]): void {
    // 1. Play alert sound
    this.playOrderSound(false);

    // 2. Dispatch custom event for badges/bells
    try {
      window.dispatchEvent(new CustomEvent('order-sound:order-received', { detail: { count: orders.length } }));
    } catch {}

    // 3. Refresh notification summary badges
    this.notificationSummaryService.refresh();

    // 4. Display floating notification banners
    orders.forEach((order) => {
      const item: NewOrderItem = { ...order, visible: true };
      this.recentNewOrders.push(item);

      // Auto dismiss after 15 seconds
      setTimeout(() => {
        this.dismissOrder(item.id);
      }, 15000);
    });

    // 5. Blink browser tab title if not focused
    if (typeof document !== 'undefined' && !document.hasFocus()) {
      const orderNum = orders[0]?.order_number || 'جديد';
      this.startTitleBlink(orderNum);
    }
  }

  public dismissOrder(id: number): void {
    const order = this.recentNewOrders.find((o) => o.id === id);
    if (order) {
      order.visible = false;
      setTimeout(() => {
        this.recentNewOrders = this.recentNewOrders.filter((o) => o.id !== id);
      }, 350);
    }
  }

  public openOrder(id: number): void {
    this.dismissOrder(id);
    this.router.navigate(['/orders']);
  }

  public playOrderSound(isTest = false): void {
    const isMuted = localStorage.getItem('admin_order_sound_muted') === 'true';
    if (isMuted && !isTest) {
      return;
    }

    this.unlockAudio();

    // 1. Try HTML Audio with new-order.wav asset first
    try {
      const audio = new Audio('assets/sounds/new-order.wav');
      audio.volume = 1.0;
      const playPromise = audio.play();
      if (playPromise !== undefined) {
        playPromise.catch(() => {
          // If HTML5 audio is blocked by autoplay policy, synthesize via resumed Web Audio context
          this.synthesizeChime();
        });
      }
    } catch {
      this.synthesizeChime();
    }
  }

  public synthesizeChime(): boolean {
    try {
      const AudioCtx = (window as any).AudioContext || (window as any).webkitAudioContext;
      if (!AudioCtx) return false;

      if (!this.audioContext) {
        this.audioContext = new AudioCtx();
      }
      const ctx = this.audioContext;
      if (ctx.state === 'suspended') {
        ctx.resume();
      }

      const now = ctx.currentTime;
      // Rich 4-tone cashier chime matching best-market: E5 (659Hz), G#5 (830Hz), B5 (988Hz), E6 (1318Hz)
      const notes = [
        { freq: 659.25, start: 0.00, dur: 0.35, gain: 0.25 },
        { freq: 830.61, start: 0.10, dur: 0.35, gain: 0.28 },
        { freq: 987.77, start: 0.20, dur: 0.40, gain: 0.30 },
        { freq: 1318.51, start: 0.30, dur: 0.70, gain: 0.35 }
      ];

      const sequences = [0.0, 0.55];

      sequences.forEach((offset) => {
        notes.forEach((note) => {
          const osc = ctx.createOscillator();
          const gainNode = ctx.createGain();

          osc.type = 'sine';
          osc.frequency.setValueAtTime(note.freq, now + offset + note.start);

          const harmonic = ctx.createOscillator();
          const harmonicGain = ctx.createGain();
          harmonic.type = 'triangle';
          harmonic.frequency.setValueAtTime(note.freq * 2, now + offset + note.start);

          gainNode.gain.setValueAtTime(0.0001, now + offset + note.start);
          gainNode.gain.linearRampToValueAtTime(note.gain, now + offset + note.start + 0.015);
          gainNode.gain.exponentialRampToValueAtTime(0.0001, now + offset + note.start + note.dur);

          harmonicGain.gain.setValueAtTime(0.0001, now + offset + note.start);
          harmonicGain.gain.linearRampToValueAtTime(note.gain * 0.2, now + offset + note.start + 0.015);
          harmonicGain.gain.exponentialRampToValueAtTime(0.0001, now + offset + note.start + note.dur * 0.7);

          osc.connect(gainNode);
          harmonic.connect(harmonicGain);
          gainNode.connect(ctx.destination);
          harmonicGain.connect(ctx.destination);

          osc.start(now + offset + note.start);
          harmonic.start(now + offset + note.start);
          osc.stop(now + offset + note.start + note.dur + 0.05);
          harmonic.stop(now + offset + note.start + note.dur + 0.05);
        });
      });

      return true;
    } catch {
      return false;
    }
  }

  private startTitleBlink(orderNum: string): void {
    this.stopTitleBlink();
    let isAlt = false;
    this.titleInterval = setInterval(() => {
      document.title = isAlt ? `(1) 🛍️ طلب جديد ${orderNum}!` : `🔔 طلب جديد وصل! - JTAK Market`;
      isAlt = !isAlt;
    }, 1200);
  }

  private stopTitleBlink(): void {
    if (this.titleInterval) {
      clearInterval(this.titleInterval);
      this.titleInterval = null;
      if (this.originalTitle) {
        document.title = this.originalTitle;
      }
    }
  }

  ngOnDestroy(): void {
    if (this.pollSub) {
      this.pollSub.unsubscribe();
      this.pollSub = null;
    }
    this.stopTitleBlink();
    if (this.focusHandler) {
      window.removeEventListener('focus', this.focusHandler);
    }
    if (this.testSoundHandler) {
      window.removeEventListener('order-sound:play-test', this.testSoundHandler);
    }
    if (this.unlockHandler) {
      window.removeEventListener('click', this.unlockHandler);
      window.removeEventListener('keydown', this.unlockHandler);
      window.removeEventListener('touchstart', this.unlockHandler);
    }
  }
}
