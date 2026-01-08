#!/usr/bin/env python3
"""
sparse_embedding_compressor.py — Compressed embedding storage for server.
Product quantization + Huffman coding, retrieval/decompress API.
"""

import argparse
import json
import logging
import pickle
from pathlib import Path
from collections import Counter
import heapq
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description='Sparse embedding compressor')
    parser.add_argument('--input', type=str, help='Input embeddings (npy)')
    parser.add_argument('--output_dir', type=str, default='./compressed_embeddings')
    parser.add_argument('--n_subvectors', type=int, default=8, help='Number of subvectors for PQ')
    parser.add_argument('--n_centroids', type=int, default=256, help='Centroids per subvector')
    parser.add_argument('--compress', action='store_true')
    parser.add_argument('--retrieve', type=str, help='Retrieve embedding by ID')
    return parser.parse_args()


class ProductQuantizer:
    """Product quantization for embedding compression."""

    def __init__(self, n_subvectors=8, n_centroids=256):
        self.n_subvectors = n_subvectors
        self.n_centroids = n_centroids
        self.codebooks = None
        self.subvector_dim = None

    def fit(self, embeddings):
        """Fit codebooks on embeddings."""
        from sklearn.cluster import KMeans

        n_samples, dim = embeddings.shape
        self.subvector_dim = dim // self.n_subvectors

        self.codebooks = []

        for i in range(self.n_subvectors):
            start = i * self.subvector_dim
            end = start + self.subvector_dim
            subvectors = embeddings[:, start:end]

            kmeans = KMeans(n_clusters=self.n_centroids, random_state=42, n_init=10)
            kmeans.fit(subvectors)

            self.codebooks.append(kmeans.cluster_centers_)

        logger.info(f"Fitted {self.n_subvectors} codebooks with {self.n_centroids} centroids")

    def encode(self, embeddings):
        """Encode embeddings to codes."""
        n_samples = len(embeddings)
        codes = np.zeros((n_samples, self.n_subvectors), dtype=np.uint8)

        for i in range(self.n_subvectors):
            start = i * self.subvector_dim
            end = start + self.subvector_dim
            subvectors = embeddings[:, start:end]

            # Find nearest centroid
            distances = np.linalg.norm(
                subvectors[:, np.newaxis] - self.codebooks[i],
                axis=2
            )
            codes[:, i] = np.argmin(distances, axis=1)

        return codes

    def decode(self, codes):
        """Decode codes to embeddings."""
        n_samples = len(codes)
        dim = self.subvector_dim * self.n_subvectors
        embeddings = np.zeros((n_samples, dim), dtype=np.float32)

        for i in range(self.n_subvectors):
            start = i * self.subvector_dim
            end = start + self.subvector_dim
            embeddings[:, start:end] = self.codebooks[i][codes[:, i]]

        return embeddings


class HuffmanCoder:
    """Huffman coding for code compression."""

    def __init__(self):
        self.codes = {}
        self.tree = None

    def fit(self, data):
        """Build Huffman tree from data."""
        freq = Counter(tuple(d) for d in data)

        # Build priority queue
        heap = [[count, [symbol, ""]] for symbol, count in freq.items()]
        heapq.heapify(heap)

        while len(heap) > 1:
            lo = heapq.heappop(heap)
            hi = heapq.heappop(heap)
            for pair in lo[1:]:
                pair[1] = '0' + pair[1]
            for pair in hi[1:]:
                pair[1] = '1' + pair[1]
            heapq.heappush(heap, [lo[0] + hi[0]] + lo[1:] + hi[1:])

        self.codes = {symbol: code for symbol, code in heap[0][1:]}
        # Reverse mapping for decode
        self.reverse_codes = {code: symbol for symbol, code in self.codes.items()}

    def encode(self, data):
        """Encode data to bit string."""
        bits = ''.join(self.codes[tuple(d)] for d in data)
        return bits

    def decode(self, bits):
        """Decode bit string to data."""
        result = []
        current = ''
        for bit in bits:
            current += bit
            if current in self.reverse_codes:
                result.append(self.reverse_codes[current])
                current = ''
        return result


def compress_embeddings(embeddings, output_dir, n_subvectors, n_centroids):
    """Compress embeddings using PQ + Huffman."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    original_size = embeddings.nbytes

    # Product quantization
    pq = ProductQuantizer(n_subvectors, n_centroids)
    pq.fit(embeddings)
    codes = pq.encode(embeddings)

    # Huffman coding
    huffman = HuffmanCoder()
    huffman.fit(codes)

    # Save compressed
    with open(output_dir / 'pq_codebooks.pkl', 'wb') as f:
        pickle.dump(pq.codebooks, f)

    with open(output_dir / 'huffman_codes.pkl', 'wb') as f:
        pickle.dump(huffman.codes, f)

    np.save(output_dir / 'compressed_codes.npy', codes)

    compressed_size = (
        (output_dir / 'pq_codebooks.pkl').stat().st_size +
        (output_dir / 'huffman_codes.pkl').stat().st_size +
        (output_dir / 'compressed_codes.npy').stat().st_size
    )

    compression_ratio = original_size / compressed_size

    logger.info(f"Original: {original_size / 1024:.1f} KB")
    logger.info(f"Compressed: {compressed_size / 1024:.1f} KB")
    logger.info(f"Compression ratio: {compression_ratio:.1f}x")

    return {'original_kb': original_size / 1024, 'compressed_kb': compressed_size / 1024,
            'ratio': compression_ratio}


def retrieve_embedding(embedding_id, output_dir):
    """Retrieve and decompress embedding."""
    output_dir = Path(output_dir)

    # Load codebooks
    with open(output_dir / 'pq_codebooks.pkl', 'rb') as f:
        codebooks = pickle.load(f)

    # Load codes
    codes = np.load(output_dir / 'compressed_codes.npy')

    # Create PQ decoder
    pq = ProductQuantizer(len(codebooks), len(codebooks[0]))
    pq.codebooks = codebooks
    pq.subvector_dim = codebooks[0].shape[1]

    # Decode specific embedding
    idx = int(embedding_id)
    embedding = pq.decode(codes[idx:idx+1])[0]

    return embedding


def main():
    args = parse_args()

    if args.compress:
        if not args.input:
            # Generate sample embeddings
            embeddings = np.random.randn(1000, 512).astype(np.float32)
        else:
            embeddings = np.load(args.input)

        logger.info(f"Compressing {len(embeddings)} embeddings")
        stats = compress_embeddings(embeddings, args.output_dir, args.n_subvectors, args.n_centroids)
        print(json.dumps(stats, indent=2))

    elif args.retrieve:
        embedding = retrieve_embedding(args.retrieve, args.output_dir)
        print(f"Retrieved embedding shape: {embedding.shape}")
        print(f"First 10 values: {embedding[:10]}")

    else:
        logger.error("Specify --compress or --retrieve")


if __name__ == '__main__':
    main()
