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

%% 0. 配置路径 & 参数
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
baseDir  = fullfile(projRoot,'GUI_results','AllCenters','CP_centers_all');
lutFile  = fullfile(projRoot,'GUI_results','AllCenters','GUI_LUT_allCenters.mat');
outFile  = fullfile(projRoot,'GUI_results','AllCenters','BoW_allCenters.mat');
K_bow    = 500;   % 词袋词汇数量
maxIter  = 100;   % 自定义 K-means 最大迭代次数

%% 1. 加载全局 LUT
if ~exist(lutFile,'file')
    error('未找到全局 GUI_LUT: %s', lutFile);
end
tmp     = load(lutFile,'LUT_all');
LUT_all = tmp.LUT_all;      % cell[nSamples×5]: {subjectID,idx_center,idx_range,prediction,probs}
nSamples = size(LUT_all,1);

%% 2. 提取每个样本的原始谱图窗口片段
SS = cell(nSamples,1);
event_idx = [];
for i = 1:nSamples
    subjectID  = LUT_all{i,1};    % e.g. 'ICARE_0015'
    idx_center = LUT_all{i,2};    % e.g. 3
    idx_range  = LUT_all{i,3};    % [start,end]
    dd = diff(idx_range) + 1;

    sampleFile = sprintf('%s_%03d.mat', subjectID, idx_center);
    samplePath = fullfile(baseDir, sampleFile);
    if ~exist(samplePath,'file')
        warning('跳过缺失文件: %s', sampleFile);
        continue;
    end

    M = load(samplePath,'Sparsed');
    Sparsed = M.Sparsed;  % cell[nCh×2], 第一列是 raw spect

    rawSpec = cell2mat(Sparsed(:,1));    % [featDim × totalWins]
    mid     = round(size(rawSpec,2)/2);
    Lc      = max(1, mid - floor(dd/2));
    Rc      = min(size(rawSpec,2), Lc + dd - 1);
    clip    = rawSpec(:, Lc:Rc)';        % [dd × featDim]

    SS{i} = clip;
    event_idx = [event_idx; i * ones(size(clip,1),1)];
end

%% 3. 聚合并预处理谱图数据
X = cell2mat(SS);        % [总窗口数 × featDim]
S = 10 * log10(X + eps); % 转 dB
S(S < -10) = -10;
S(S > 25)  = 25;

%% 4. 自定义 K-means 构建 codebook
rng('default');
numWin = size(S,1);
% (a) 随机挑 K_bow 个初始化质心
perm = randperm(numWin, min(K_bow, numWin));
centroids = S(perm,:);
assignments = zeros(numWin,1);

for iter = 1:maxIter
    % (b) 分配
    for j = 1:numWin
        [~, assignments(j)] = min(sum((centroids - S(j,:)).^2, 2));
    end
    % (c) 更新
    newCent = centroids;
    for k = 1:size(centroids,1)
        members = S(assignments==k, :);
        if ~isempty(members)
            newCent(k,:) = mean(members,1);
        end
    end
    if max(abs(newCent(:) - centroids(:))) < 1e-6
        fprintf('K-means 在迭代 %d 时收敛\n', iter);
        break;
    end
    centroids = newCent;
end

%% 5. 生成每个样本的归一化 BoW 直方图
bow_vec = zeros(nSamples, size(centroids,1));
for i = 1:nSamples
    idx = find(event_idx == i);
    if isempty(idx), continue; end
    h = histcounts(assignments(idx), 1:(size(centroids,1)+1));
    bow_vec(i,:) = h ./ sum(h);
end

%% 6. 保存结果
save(outFile, 'bow_vec', 'assignments', 'K_bow');
fprintf('✅ 全局 BoW 特征已保存到 %s\n', outFile);