#!/usr/bin/env python3
"""
peer_sync_optimizer.py - LAN-only sync between parent/kid devices

Allows optional local network syncing between devices to avoid cloud
calls when both devices are on the same network.
"""

import argparse
import json
import socket
import hashlib
import threading
import time
import logging
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import struct

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


# Protocol constants
DISCOVERY_PORT = 5353
SYNC_PORT = 5354
MAGIC = b'KOMAL'
VERSION = 1


class PeerDiscovery:
    """Discover peers on local network."""

    def __init__(self, device_id: str, device_type: str):
        self.device_id = device_id
        self.device_type = device_type  # 'parent' or 'child'
        self.peers = {}
        self.running = False

    def _get_broadcast_address(self) -> str:
        """Get broadcast address for local network."""
        # Simplified - in production would detect actual network
        return '255.255.255.255'

    def _create_announcement(self) -> bytes:
        """Create discovery announcement packet."""
        data = {
            'device_id': self.device_id,
            'device_type': self.device_type,
            'sync_port': SYNC_PORT,
            'timestamp': time.time()
        }
        payload = json.dumps(data).encode('utf-8')
        return MAGIC + struct.pack('!BH', VERSION, len(payload)) + payload

    def _parse_announcement(self, data: bytes) -> Optional[Dict]:
        """Parse discovery announcement."""
        if not data.startswith(MAGIC):
            return None

        try:
            version = data[5]
            length = struct.unpack('!H', data[6:8])[0]
            payload = json.loads(data[8:8+length].decode('utf-8'))
            return payload
        except:
            return None

    def start_discovery(self):
        """Start discovery service."""
        self.running = True

        # Start listener
        listener_thread = threading.Thread(target=self._listen_loop, daemon=True)
        listener_thread.start()

        # Start announcer
        announcer_thread = threading.Thread(target=self._announce_loop, daemon=True)
        announcer_thread.start()

        logger.info(f"Discovery started for {self.device_id} ({self.device_type})")

    def stop_discovery(self):
        """Stop discovery service."""
        self.running = False

    def _listen_loop(self):
        """Listen for peer announcements."""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.settimeout(1.0)

        try:
            sock.bind(('', DISCOVERY_PORT))
        except:
            logger.error("Could not bind discovery port")
            return

        while self.running:
            try:
                data, addr = sock.recvfrom(1024)
                peer = self._parse_announcement(data)

                if peer and peer['device_id'] != self.device_id:
                    peer['address'] = addr[0]
                    peer['last_seen'] = time.time()
                    self.peers[peer['device_id']] = peer

                    logger.debug(f"Discovered peer: {peer['device_id']} at {addr[0]}")
            except socket.timeout:
                continue
            except Exception as e:
                logger.error(f"Discovery error: {e}")

        sock.close()

    def _announce_loop(self):
        """Broadcast announcements."""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

        while self.running:
            try:
                announcement = self._create_announcement()
                sock.sendto(announcement, (self._get_broadcast_address(), DISCOVERY_PORT))
            except Exception as e:
                logger.error(f"Announcement error: {e}")

            time.sleep(5)  # Announce every 5 seconds

        sock.close()

    def get_peers(self, max_age: float = 30.0) -> List[Dict]:
        """Get recently seen peers."""
        now = time.time()
        active = []

        for peer in self.peers.values():
            if now - peer['last_seen'] < max_age:
                active.append(peer)

        return active


class PeerSyncClient:
    """Sync data with peers."""

    def __init__(self, device_id: str):
        self.device_id = device_id

    def sync_to_peer(self, peer: Dict, data: Dict) -> Dict:
        """Sync data to a peer device."""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10.0)
            sock.connect((peer['address'], peer['sync_port']))

            # Send sync request
            request = {
                'type': 'sync',
                'from_device': self.device_id,
                'data': data,
                'timestamp': time.time()
            }

            payload = json.dumps(request).encode('utf-8')
            sock.sendall(struct.pack('!I', len(payload)) + payload)

            # Receive response
            length_data = sock.recv(4)
            if len(length_data) < 4:
                return {'success': False, 'error': 'No response'}

            length = struct.unpack('!I', length_data)[0]
            response_data = b''

            while len(response_data) < length:
                chunk = sock.recv(min(4096, length - len(response_data)))
                if not chunk:
                    break
                response_data += chunk

            sock.close()

            response = json.loads(response_data.decode('utf-8'))
            return response

        except Exception as e:
            return {'success': False, 'error': str(e)}


class PeerSyncServer:
    """Server to receive sync requests from peers."""

    def __init__(self, device_id: str, on_sync_received):
        self.device_id = device_id
        self.on_sync_received = on_sync_received
        self.running = False

    def start(self):
        """Start sync server."""
        self.running = True
        thread = threading.Thread(target=self._server_loop, daemon=True)
        thread.start()
        logger.info(f"Sync server started on port {SYNC_PORT}")

    def stop(self):
        """Stop sync server."""
        self.running = False

    def _server_loop(self):
        """Server loop to accept connections."""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.settimeout(1.0)

        try:
            sock.bind(('', SYNC_PORT))
            sock.listen(5)
        except Exception as e:
            logger.error(f"Could not start sync server: {e}")
            return

        while self.running:
            try:
                client, addr = sock.accept()
                thread = threading.Thread(
                    target=self._handle_client,
                    args=(client, addr),
                    daemon=True
                )
                thread.start()
            except socket.timeout:
                continue
            except Exception as e:
                logger.error(f"Server error: {e}")

        sock.close()

    def _handle_client(self, client: socket.socket, addr: Tuple):
        """Handle a client connection."""
        try:
            client.settimeout(10.0)

            # Receive request
            length_data = client.recv(4)
            if len(length_data) < 4:
                return

            length = struct.unpack('!I', length_data)[0]
            request_data = b''

            while len(request_data) < length:
                chunk = client.recv(min(4096, length - len(request_data)))
                if not chunk:
                    break
                request_data += chunk

            request = json.loads(request_data.decode('utf-8'))

            # Process sync
            if request.get('type') == 'sync':
                result = self.on_sync_received(request['from_device'], request['data'])
                response = {'success': True, 'result': result}
            else:
                response = {'success': False, 'error': 'Unknown request type'}

            # Send response
            payload = json.dumps(response).encode('utf-8')
            client.sendall(struct.pack('!I', len(payload)) + payload)

        except Exception as e:
            logger.error(f"Client handler error: {e}")
        finally:
            client.close()


class PeerSyncOptimizer:
    """Main peer sync optimizer."""

    def __init__(self, device_id: str, device_type: str):
        self.device_id = device_id
        self.device_type = device_type

        self.discovery = PeerDiscovery(device_id, device_type)
        self.client = PeerSyncClient(device_id)
        self.server = PeerSyncServer(device_id, self._on_sync_received)

        self.sync_log = []
        self.received_data = []

    def _on_sync_received(self, from_device: str, data: Dict) -> Dict:
        """Handle received sync data."""
        logger.info(f"Received sync from {from_device}: {len(json.dumps(data))} bytes")

        self.received_data.append({
            'from': from_device,
            'data': data,
            'timestamp': datetime.now().isoformat()
        })

        return {'status': 'received', 'device': self.device_id}

    def start(self):
        """Start peer sync services."""
        self.discovery.start_discovery()
        self.server.start()
        logger.info("Peer sync optimizer started")

    def stop(self):
        """Stop peer sync services."""
        self.discovery.stop_discovery()
        self.server.stop()

    def sync_data(self, data: Dict) -> List[Dict]:
        """Sync data to all available peers."""
        peers = self.discovery.get_peers()
        results = []

        for peer in peers:
            # Only sync to complementary device types
            if self.device_type == 'child' and peer['device_type'] != 'parent':
                continue
            if self.device_type == 'parent' and peer['device_type'] != 'child':
                continue

            result = self.client.sync_to_peer(peer, data)
            result['peer_id'] = peer['device_id']

            self.sync_log.append({
                'peer': peer['device_id'],
                'success': result['success'],
                'timestamp': datetime.now().isoformat()
            })

            results.append(result)
            logger.info(f"Synced to {peer['device_id']}: {'OK' if result['success'] else result.get('error')}")

        return results

    def get_stats(self) -> Dict:
        """Get sync statistics."""
        successful = sum(1 for s in self.sync_log if s['success'])

        return {
            'peers_found': len(self.discovery.get_peers()),
            'total_syncs': len(self.sync_log),
            'successful_syncs': successful,
            'received_syncs': len(self.received_data),
            'cloud_calls_avoided': successful
        }


def main():
    parser = argparse.ArgumentParser(description='Peer sync optimizer')
    parser.add_argument('--device-id', type=str, required=True, help='Device ID')
    parser.add_argument('--device-type', type=str, choices=['parent', 'child'], required=True)
    parser.add_argument('--duration', type=int, default=30, help='Run duration in seconds')
    parser.add_argument('--sync-test', action='store_true', help='Send test sync data')

    args = parser.parse_args()

    optimizer = PeerSyncOptimizer(args.device_id, args.device_type)
    optimizer.start()

    try:
        start = time.time()

        while time.time() - start < args.duration:
            peers = optimizer.discovery.get_peers()

            if peers:
                logger.info(f"Found {len(peers)} peer(s): {[p['device_id'] for p in peers]}")

                if args.sync_test:
                    # Send test sync
                    test_data = {
                        'type': 'session_update',
                        'metrics': {'attention': 0.85, 'engagement': 0.9},
                        'timestamp': datetime.now().isoformat()
                    }

                    results = optimizer.sync_data(test_data)
                    for r in results:
                        status = 'OK' if r['success'] else r.get('error', 'failed')
                        logger.info(f"Sync to {r['peer_id']}: {status}")

            time.sleep(5)

        # Stats
        stats = optimizer.get_stats()
        logger.info(f"\n=== Peer Sync Stats ===")
        logger.info(f"Peers found: {stats['peers_found']}")
        logger.info(f"Total syncs: {stats['total_syncs']}")
        logger.info(f"Successful: {stats['successful_syncs']}")
        logger.info(f"Received: {stats['received_syncs']}")
        logger.info(f"Cloud calls avoided: {stats['cloud_calls_avoided']}")

    except KeyboardInterrupt:
        logger.info("Interrupted")
    finally:
        optimizer.stop()


if __name__ == '__main__':
    main()
