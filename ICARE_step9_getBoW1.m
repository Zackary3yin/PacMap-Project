%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step9_build_BoW_allCenters.m (revised)
% 说明：基于新版GUI_LUT，全局构建 BoW 特征：
%   1. 读取 GUI_LUT_allCenters.mat 获得 subjectID、idx_center、idx_range
%   2. 从 CP_centers_all 中提取每个样本的谱图片段
%   3. 聚合所有片段并转 dB，截断到 [-10,25]
%   4. 自定义 K-means（K_bow 质心）构建 codebook
%   5. 为每个样本生成归一化 BoW 直方图
%   6. 保存到 BoW_allCenters.mat
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

%% 0) 配置路径 & 参数
projRoot = fileparts(mfilename('fullpath'));                                  %%% 修改：以"当前脚本目录"为根
baseDir  = fullfile(projRoot,'GUI_results','AllCenters','CP_centers_all');    %%% 修改
lutFile  = fullfile(projRoot,'GUI_results','AllCenters','GUI_LUT_allCenters.mat'); %%% 修改
outFile  = fullfile(projRoot,'GUI_results','AllCenters','BoW_allCenters.mat');     %%% 修改

K_bow    = 500;   % 词袋词汇数量
maxIter  = 100;   % 自定义 K-means 最大迭代次数
db_min   = -10;   % dB 下限                                                     %%% 修改：参数集中
db_max   =  25;   % dB 上限                                                     %%% 修改

%% 1) 加载全局 LUT
if ~exist(lutFile,'file')
    error('未找到全局 GUI_LUT: %s', lutFile);
end
tmp      = load(lutFile,'LUT_all');
LUT_all  = tmp.LUT_all;      % cell[nSamples×5]: {subjectID,idx_center,idx_range,prediction,probs}
nSamples = size(LUT_all,1);
if nSamples == 0
    error('LUT_all 为空：%s', lutFile);
end

%% 2) 提取每个样本的原始谱图窗口片段
if ~exist(baseDir,'dir')
    error('未找到 CP_centers_all 目录：%s', baseDir);
end

SS = cell(nSamples,1);
event_idx = [];

for i = 1:nSamples
    subjectID  = LUT_all{i,1};    % e.g. 'ICARE_0015'
    idx_center = LUT_all{i,2};    % e.g. 3
    idx_range  = LUT_all{i,3};    % [start,end]
    if isempty(idx_range) || numel(idx_range)~=2
        warning('(%d/%d) idx_range 非法，跳过：%s_%03d', i, nSamples, subjectID, idx_center);
        continue;
    end
    dd = diff(idx_range) + 1;

    sampleFile = sprintf('%s_%03d.mat', subjectID, idx_center);
    samplePath = fullfile(baseDir, sampleFile);
    if ~exist(samplePath,'file')
        warning('跳过缺失文件: %s', sampleFile);
        continue;
    end

    M = load(samplePath,'Sparsed');
    if ~isfield(M,'Sparsed') || isempty(M.Sparsed) || size(M.Sparsed,2) < 1
        warning('Sparsed 结构异常，跳过：%s', sampleFile);
        continue;
    end

    % 说明：
    % 在 Step7 中我们保存的 Sparsed = SDATA，并将"解析后的片段"写在第2列。
    % 第1列仍保留的是原始区域谱图，因此这里取 Sparsed(:,1) 以 raw 为基础再居中裁剪。
    try
        rawSpec = cell2mat(M.Sparsed(:,1));   % [featDim × totalWins]
    catch
        warning('无法拼接 Sparsed(:,1)，跳过：%s', sampleFile);
        continue;
    end
    if isempty(rawSpec) || size(rawSpec,2) < 1
        warning('rawSpec 为空，跳过：%s', sampleFile);
        continue;
    end

    mid = round(size(rawSpec,2)/2);
    Lc  = max(1, mid - floor(dd/2));
    Rc  = min(size(rawSpec,2), Lc + dd - 1);
    if Rc < Lc
        warning('窗口计算异常(Lc>Rc)，跳过：%s', sampleFile);
        continue;
    end

    clip = rawSpec(:, Lc:Rc)';     % [dd × featDim]
    % 过滤非有限值
    clip(~isfinite(clip)) = 0;

    SS{i} = clip;
    event_idx = [event_idx; i * ones(size(clip,1),1)]; %#ok<AGROW>
end

% 拼接所有样本窗口
nonempty = ~cellfun(@isempty, SS);
if ~any(nonempty)
    error('没有可用的谱图片段，无法构建 BoW。');
end
X = cell2mat(SS(nonempty));   % [总窗口数 × featDim]
if isempty(X)
    error('谱图片段拼接结果为空。');
end

%% 3) 聚合并预处理谱图数据
S = 10 * log10(X + eps);         % 转 dB
S(S < db_min) = db_min;          %%% 修改：阈值参数化
S(S > db_max) = db_max;          %%% 修改
S(~isfinite(S)) = 0;             % 保护

%% 4) 自定义 K-means 构建 codebook
rng('default');
numWin = size(S,1);
if numWin < 2
    error('可用窗口数过少(%d)，无法运行 K-means。', numWin);
end

K_eff = min(K_bow, numWin);      %%% 修改：有效 K，避免 K > 样本数
perm = randperm(numWin, K_eff);
centroids = S(perm,:);
assignments = zeros(numWin,1);

for iter = 1:maxIter
    % (a) 分配
    % 向量化实现以提速
    % 距离矩阵 D_ij = ||S_i - C_j||^2
    % 由于数据可能较大，如内存吃紧可改回逐样本循环
    D = pdist2(S, centroids, 'euclidean').^2;    %%% 修改：向量化、数值稳定
    [~, assignments] = min(D, [], 2);

    % (b) 更新
    newCent = centroids;
    for k = 1:K_eff
        members = S(assignments==k, :);
        if ~isempty(members)
            newCent(k,:) = mean(members,1);
        end
    end

    % (c) 收敛判定
    if max(abs(newCent(:) - centroids(:))) < 1e-6
        fprintf('K-means 在迭代 %d 时收敛\n', iter);
        centroids = newCent;
        break;
    end
    centroids = newCent;
end

%% 5) 生成每个样本的归一化 BoW 直方图
bow_vec = zeros(nSamples, K_eff);
event_idx = event_idx(:);
for i = 1:nSamples
    idx = find(event_idx == i);
    if isempty(idx), continue; end
    h = histcounts(assignments(idx), 1:(K_eff+1));
    s = sum(h);
    if s == 0
        bow_vec(i,:) = 0;
    else
        bow_vec(i,:) = h ./ s;
    end
end

%% 6) 保存结果
if ~exist(fileparts(outFile), 'dir')
    mkdir(fileparts(outFile));
end
save(outFile, 'bow_vec', 'assignments', 'centroids', 'K_bow', 'K_eff');       %%% 修改：同时保存质心与有效 K
fprintf('✅ 全局 BoW 特征已保存到 %s（样本=%d，窗口=%d，K=%d）\n', outFile, nSamples, numWin, K_eff);