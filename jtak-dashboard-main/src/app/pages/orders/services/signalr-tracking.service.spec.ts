import * as signalR from '@microsoft/signalr';
import { SignalrTrackingService } from './signalr-tracking.service';

describe('Tracking connection lifecycle', () => {
  let hub: any; let service: SignalrTrackingService; let release: () => void;
  beforeEach(() => {
    const pending = new Promise<void>(resolve => release = resolve);
    hub = { state: signalR.HubConnectionState.Disconnected,
      start: jasmine.createSpy('start').and.callFake(async () => { hub.state = signalR.HubConnectionState.Connecting; await pending; hub.state = signalR.HubConnectionState.Connected; }),
      stop: jasmine.createSpy('stop').and.resolveTo(), invoke: jasmine.createSpy('invoke').and.resolveTo(),
      on: () => {}, onclose: () => {}, onreconnecting: () => {}, onreconnected: () => {} };
    spyOn(signalR.HubConnectionBuilder.prototype, 'build').and.returnValue(hub);
    service = new SignalrTrackingService({ getAuthFromSessionStorage: () => null, getAuthFromLocalStorage: () => null } as any, 'browser');
  });
  it('simultaneous modal starts share one connection', async () => {
    const first = service.startConnection(); const second = service.startConnection(); release();
    await Promise.all([first, second]); expect(hub.start).toHaveBeenCalledTimes(1); await service.stopConnection();
  });
  it('closing a modal while connecting does not join its order later', async () => {
    const tracking = service.trackOrder(16); await service.untrackOrder(16); release(); await tracking;
    expect(hub.invoke).not.toHaveBeenCalledWith('JoinOrderTracking', 16); await service.stopConnection();
  });
  it('closing the session during startup clears all requested groups', async () => {
    const tracking = service.trackOrder(16); const stopped = service.stopConnection(); release();
    await Promise.all([tracking, stopped]); expect(hub.stop).toHaveBeenCalledTimes(1);
    expect(hub.invoke).not.toHaveBeenCalledWith('JoinOrderTracking', 16);
  });
});
