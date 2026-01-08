"""
multimodal_transformer.py — Core model architecture for Komal multimodal pretraining.

Supports gaze, audio (spectrogram), face, and touch modalities with
masked modeling objective.
"""

import math
import torch
import torch.nn as nn
import torch.nn.functional as F
from typing import Dict, Optional, Tuple


class PositionalEncoding(nn.Module):
    """Sinusoidal positional encoding."""

    def __init__(self, d_model: int, max_len: int = 5000, dropout: float = 0.1):
        super().__init__()
        self.dropout = nn.Dropout(p=dropout)

        pe = torch.zeros(max_len, d_model)
        position = torch.arange(0, max_len, dtype=torch.float).unsqueeze(1)
        div_term = torch.exp(torch.arange(0, d_model, 2).float() * (-math.log(10000.0) / d_model))
        pe[:, 0::2] = torch.sin(position * div_term)
        pe[:, 1::2] = torch.cos(position * div_term)
        pe = pe.unsqueeze(0)
        self.register_buffer('pe', pe)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = x + self.pe[:, :x.size(1)]
        return self.dropout(x)


class ModalityEncoder(nn.Module):
    """Encoder for a single modality."""

    def __init__(self, input_dim: int, model_dim: int, dropout: float = 0.1):
        super().__init__()
        self.proj = nn.Linear(input_dim, model_dim)
        self.norm = nn.LayerNorm(model_dim)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.dropout(self.norm(self.proj(x)))


class GazeEncoder(ModalityEncoder):
    """Encoder for gaze/eye-tracking sequences."""

    def __init__(self, model_dim: int, dropout: float = 0.1):
        # gaze: x, y, timestamp, pupil_size, velocity
        super().__init__(input_dim=5, model_dim=model_dim, dropout=dropout)


class AudioEncoder(ModalityEncoder):
    """Encoder for audio spectrograms."""

    def __init__(self, n_mels: int, model_dim: int, dropout: float = 0.1):
        super().__init__(input_dim=n_mels, model_dim=model_dim, dropout=dropout)
        # add conv layers for local patterns
        self.conv = nn.Sequential(
            nn.Conv1d(n_mels, model_dim // 2, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.Conv1d(model_dim // 2, model_dim, kernel_size=3, padding=1),
            nn.ReLU(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: [B, T, n_mels]
        x = x.transpose(1, 2)  # [B, n_mels, T]
        x = self.conv(x)  # [B, model_dim, T]
        x = x.transpose(1, 2)  # [B, T, model_dim]
        return self.dropout(self.norm(x))


class FaceEncoder(ModalityEncoder):
    """Encoder for face/micro-expression features."""

    def __init__(self, input_dim: int, model_dim: int, dropout: float = 0.1):
        # face: flattened features or pre-extracted embeddings
        super().__init__(input_dim=input_dim, model_dim=model_dim, dropout=dropout)


class TouchEncoder(ModalityEncoder):
    """Encoder for touch/gesture sequences."""

    def __init__(self, model_dim: int, dropout: float = 0.1):
        # touch: x, y, pressure, timestamp, velocity
        super().__init__(input_dim=5, model_dim=model_dim, dropout=dropout)


class MultimodalTransformer(nn.Module):
    """
    Multimodal transformer for SEL assessment.

    Processes gaze, audio, face, and touch modalities with cross-modal attention.
    """

    def __init__(
        self,
        model_dim: int = 768,
        ffn_dim: int = 3072,
        num_layers: int = 12,
        num_heads: int = 12,
        dropout: float = 0.1,
        max_seq_len: int = 1024,
        n_mels: int = 80,
        face_dim: int = 768,
        vocab_size: int = 32000,
        mask_token_id: int = 103,
    ):
        super().__init__()

        self.model_dim = model_dim
        self.mask_token_id = mask_token_id

        # modality encoders
        self.gaze_encoder = GazeEncoder(model_dim, dropout)
        self.audio_encoder = AudioEncoder(n_mels, model_dim, dropout)
        self.face_encoder = FaceEncoder(face_dim, model_dim, dropout)
        self.touch_encoder = TouchEncoder(model_dim, dropout)

        # modality type embeddings
        self.modality_embeddings = nn.Embedding(4, model_dim)  # 4 modalities

        # positional encoding
        self.pos_encoding = PositionalEncoding(model_dim, max_seq_len, dropout)

        # transformer encoder
        encoder_layer = nn.TransformerEncoderLayer(
            d_model=model_dim,
            nhead=num_heads,
            dim_feedforward=ffn_dim,
            dropout=dropout,
            activation='gelu',
            batch_first=True,
            norm_first=True,
        )
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers)

        # output heads for masked prediction
        self.gaze_head = nn.Linear(model_dim, 5)
        self.audio_head = nn.Linear(model_dim, n_mels)
        self.face_head = nn.Linear(model_dim, face_dim)
        self.touch_head = nn.Linear(model_dim, 5)

        # classification head for downstream tasks
        self.classifier = nn.Sequential(
            nn.Linear(model_dim, model_dim),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(model_dim, vocab_size),
        )

        self._init_weights()

    def _init_weights(self):
        """Initialize weights."""
        for module in self.modules():
            if isinstance(module, nn.Linear):
                nn.init.xavier_uniform_(module.weight)
                if module.bias is not None:
                    nn.init.zeros_(module.bias)
            elif isinstance(module, nn.Embedding):
                nn.init.normal_(module.weight, std=0.02)

    def encode_modalities(
        self,
        gaze: Optional[torch.Tensor] = None,
        audio: Optional[torch.Tensor] = None,
        face: Optional[torch.Tensor] = None,
        touch: Optional[torch.Tensor] = None,
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        """Encode and concatenate all modalities."""
        embeddings = []
        modality_ids = []
        batch_size = None

        if gaze is not None:
            batch_size = gaze.size(0)
            gaze_emb = self.gaze_encoder(gaze)
            embeddings.append(gaze_emb)
            modality_ids.append(torch.zeros(gaze_emb.size(1), dtype=torch.long, device=gaze.device))

        if audio is not None:
            batch_size = audio.size(0)
            audio_emb = self.audio_encoder(audio)
            embeddings.append(audio_emb)
            modality_ids.append(torch.ones(audio_emb.size(1), dtype=torch.long, device=audio.device))

        if face is not None:
            batch_size = face.size(0)
            face_emb = self.face_encoder(face)
            embeddings.append(face_emb)
            modality_ids.append(torch.full((face_emb.size(1),), 2, dtype=torch.long, device=face.device))

        if touch is not None:
            batch_size = touch.size(0)
            touch_emb = self.touch_encoder(touch)
            embeddings.append(touch_emb)
            modality_ids.append(torch.full((touch_emb.size(1),), 3, dtype=torch.long, device=touch.device))

        if not embeddings:
            raise ValueError("At least one modality must be provided")

        # concatenate all embeddings
        x = torch.cat(embeddings, dim=1)
        modality_ids = torch.cat(modality_ids, dim=0)

        # add modality embeddings
        modality_emb = self.modality_embeddings(modality_ids)
        x = x + modality_emb.unsqueeze(0).expand(batch_size, -1, -1)

        return x, modality_ids

    def forward(
        self,
        gaze: Optional[torch.Tensor] = None,
        audio: Optional[torch.Tensor] = None,
        face: Optional[torch.Tensor] = None,
        touch: Optional[torch.Tensor] = None,
        attention_mask: Optional[torch.Tensor] = None,
        return_embeddings: bool = False,
    ) -> Dict[str, torch.Tensor]:
        """
        Forward pass.

        Args:
            gaze: [B, T_gaze, 5] gaze sequences
            audio: [B, T_audio, n_mels] spectrograms
            face: [B, T_face, face_dim] face features
            touch: [B, T_touch, 5] touch sequences
            attention_mask: [B, T_total] attention mask
            return_embeddings: return transformer embeddings

        Returns:
            Dictionary with predictions and optional embeddings
        """
        # encode modalities
        x, modality_ids = self.encode_modalities(gaze, audio, face, touch)

        # add positional encoding
        x = self.pos_encoding(x)

        # create attention mask if needed
        if attention_mask is not None:
            # convert to transformer format (True = masked)
            attn_mask = ~attention_mask.bool()
        else:
            attn_mask = None

        # transformer encoding
        hidden = self.transformer(x, src_key_padding_mask=attn_mask)

        outputs = {}

        # compute predictions for each modality
        gaze_mask = modality_ids == 0
        audio_mask = modality_ids == 1
        face_mask = modality_ids == 2
        touch_mask = modality_ids == 3

        if gaze_mask.any():
            gaze_hidden = hidden[:, gaze_mask]
            outputs['gaze_pred'] = self.gaze_head(gaze_hidden)

        if audio_mask.any():
            audio_hidden = hidden[:, audio_mask]
            outputs['audio_pred'] = self.audio_head(audio_hidden)

        if face_mask.any():
            face_hidden = hidden[:, face_mask]
            outputs['face_pred'] = self.face_head(face_hidden)

        if touch_mask.any():
            touch_hidden = hidden[:, touch_mask]
            outputs['touch_pred'] = self.touch_head(touch_hidden)

        # pooled output for classification
        outputs['pooled'] = hidden.mean(dim=1)
        outputs['logits'] = self.classifier(outputs['pooled'])

        if return_embeddings:
            outputs['hidden_states'] = hidden

        return outputs


class MultimodalTransformerForPretraining(nn.Module):
    """Wrapper for masked multimodal modeling pretraining."""

    def __init__(self, config: dict):
        super().__init__()
        self.model = MultimodalTransformer(**config)
        self.mask_ratio = config.get('mask_ratio', 0.15)

    def create_masks(
        self,
        tensor: torch.Tensor,
        mask_ratio: float = 0.15
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        """Create random masks for masked modeling."""
        B, T = tensor.size(0), tensor.size(1)
        mask = torch.rand(B, T, device=tensor.device) < mask_ratio
        return mask

    def forward(
        self,
        gaze: Optional[torch.Tensor] = None,
        audio: Optional[torch.Tensor] = None,
        face: Optional[torch.Tensor] = None,
        touch: Optional[torch.Tensor] = None,
    ) -> Dict[str, torch.Tensor]:
        """Forward with masking and loss computation."""
        # store original values
        targets = {}
        masks = {}

        # apply masks
        if gaze is not None:
            masks['gaze'] = self.create_masks(gaze)
            targets['gaze'] = gaze.clone()
            gaze = gaze.clone()
            gaze[masks['gaze']] = 0

        if audio is not None:
            masks['audio'] = self.create_masks(audio)
            targets['audio'] = audio.clone()
            audio = audio.clone()
            audio[masks['audio']] = 0

        if face is not None:
            masks['face'] = self.create_masks(face)
            targets['face'] = face.clone()
            face = face.clone()
            face[masks['face']] = 0

        if touch is not None:
            masks['touch'] = self.create_masks(touch)
            targets['touch'] = touch.clone()
            touch = touch.clone()
            touch[masks['touch']] = 0

        # forward pass
        outputs = self.model(gaze, audio, face, touch)

        # compute losses
        total_loss = 0
        losses = {}

        if 'gaze_pred' in outputs and 'gaze' in targets:
            gaze_loss = F.mse_loss(
                outputs['gaze_pred'][masks['gaze']],
                targets['gaze'][masks['gaze']]
            )
            losses['gaze_loss'] = gaze_loss
            total_loss += gaze_loss

        if 'audio_pred' in outputs and 'audio' in targets:
            audio_loss = F.mse_loss(
                outputs['audio_pred'][masks['audio']],
                targets['audio'][masks['audio']]
            )
            losses['audio_loss'] = audio_loss
            total_loss += audio_loss

        if 'face_pred' in outputs and 'face' in targets:
            face_loss = F.mse_loss(
                outputs['face_pred'][masks['face']],
                targets['face'][masks['face']]
            )
            losses['face_loss'] = face_loss
            total_loss += face_loss

        if 'touch_pred' in outputs and 'touch' in targets:
            touch_loss = F.mse_loss(
                outputs['touch_pred'][masks['touch']],
                targets['touch'][masks['touch']]
            )
            losses['touch_loss'] = touch_loss
            total_loss += touch_loss

        outputs['loss'] = total_loss
        outputs['losses'] = losses

        return outputs


def create_model(args) -> MultimodalTransformerForPretraining:
    """Create model from command-line arguments."""
    config = {
        'model_dim': args.model_dim,
        'ffn_dim': args.ffn_dim,
        'num_layers': args.num_layers,
        'num_heads': args.num_heads,
        'dropout': getattr(args, 'dropout', 0.1),
        'max_seq_len': getattr(args, 'max_seq_len', 1024),
        'n_mels': getattr(args, 'n_mels', 80),
        'face_dim': getattr(args, 'face_dim', 768),
        'mask_ratio': getattr(args, 'mask_ratio', 0.15),
    }
    return MultimodalTransformerForPretraining(config)
