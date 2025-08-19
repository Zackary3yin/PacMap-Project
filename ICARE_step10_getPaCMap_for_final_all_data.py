#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
step10_plot_pacmap.py

1. 从 AllCenters/CP_centers_all/*.mat 读取:
     - feat_row (1×28)
     - scores   (1×6)
2. 用 PaCMAP 将所有 feat_row (N×28) 投影到 2D
3. matplotlib 散点图，按模型预测类别上色
4. 保存中间结果到 pacmap_coords.mat 供 MATLAB GUI(step11) 使用
"""
import os
import numpy as np
import scipy.io as sio
import pandas as pd
import matplotlib.pyplot as plt
from pacmap import PaCMAP

# ——— 配置路径 ———
# %%% 修改：以“当前脚本所在目录”为根，不再写死绝对路径
proj_root   = os.path.dirname(os.path.abspath(__file__))  # %%% 修改
seg_all_dir = os.path.join(proj_root, 'GUI_results', 'AllCenters', 'CP_centers_all')  # %%% 修改
out_matfile = os.path.join(proj_root, 'GUI_results', 'AllCenters', 'pacmap_coords.mat')  # %%% 修改
class_names = ['Seizure','LPD','GPD','LRDA','GRDA','Other']

# 目录存在性检查（更健壮）
if not os.path.isdir(seg_all_dir):
    raise FileNotFoundError(f'未找到目录：{seg_all_dir}（请先完成 Step7 的输出）')

# ——— 1. 读取所有 CP-center 文件 ———
records = []
for fn in sorted(os.listdir(seg_all_dir)):
    if not fn.endswith('.mat'):
        continue
    base = fn[:-4]
    # filename 格式 ICARE_XXXX_YYY.mat
    try:
        subject, idx_str = base.rsplit('_', 1)
        idx_center = int(idx_str)
    except ValueError:
        continue

    data = sio.loadmat(os.path.join(seg_all_dir, fn))
    feat   = data.get('feat_row', None)
    scores = data.get('scores', None)
    if feat is None or scores is None:
        # 略过缺少关键变量的样本
        continue

    feat = np.array(feat).flatten()
    scores = np.array(scores).flatten()
    # 保护：若分数长度与类别不匹配，只保留前 len(class_names) 个
    if scores.size > len(class_names):
        scores = scores[:len(class_names)]
    label = class_names[int(np.argmax(scores))]

    rec = {
        'subject'   : subject,
        'idx_center': idx_center,
        'label'     : label
    }
    # 展平 28 维特征
    for j in range(feat.size):
        rec[f'f{j}'] = float(feat[j])
    records.append(rec)

df = pd.DataFrame(records)
print(f"✅ 一共加载 {len(df)} 个 CP-center 样本")
if len(df) == 0:
    raise RuntimeError("没有可用样本，请检查 CP_centers_all 的内容。")

print("标签分布：")
print(df['label'].value_counts())

if len(df) < 2:
    raise RuntimeError("样本不足，无法做 PaCMAP（至少需要 2 个）")

# ——— 2. PaCMAP 降到 2D ———
feat_cols = [c for c in df.columns if c.startswith('f')]
X = df[feat_cols].values.astype(np.float32)
X = np.nan_to_num(X, nan=0.0, posinf=0.0, neginf=0.0)

# 可重复性：设定随机种子（不改变算法本身）
# embedder = PaCMAP(n_components=2, n_neighbors=None, MN_ratio=0.5, FP_ratio=2.0, random_state=42)
embedder = PaCMAP(n_components=2, n_neighbors=None, MN_ratio=0.5, FP_ratio=2.0)  # 与你原参数一致
XY = embedder.fit_transform(X)

df['x'] = XY[:,0]
df['y'] = XY[:,1]

# ——— 3. 散点图 ———
plt.figure(figsize=(8,6))
for lbl, grp in df.groupby('label'):
    plt.scatter(grp['x'], grp['y'], label=lbl, s=35, alpha=0.75)
plt.xlabel('PaCMAP dim 1')
plt.ylabel('PaCMAP dim 2')
plt.title('PaCMAP embedding of all CP centers\n(colored by model prediction)')
plt.legend(title='Prediction', fontsize='small', loc='best')
plt.grid(True)
plt.tight_layout()
plt.show()

# ——— 4. 保存中间结果供 MATLAB GUI 使用 ———
# %%% 修改：输出在脚本目录下 GUI_results/AllCenters/
out = {
    'subject'   : np.array(df['subject'].tolist(), dtype=object),
    'idx_center': df['idx_center'].values,
    'label'     : np.array(df['label'].tolist(), dtype=object),
    'x'         : df['x'].values,
    'y'         : df['y'].values
}
# 确保输出目录存在
os.makedirs(os.path.dirname(out_matfile), exist_ok=True)  # %%% 修改
sio.savemat(out_matfile, out)
print(f"✅ 已保存坐标和标签到 {out_matfile}")