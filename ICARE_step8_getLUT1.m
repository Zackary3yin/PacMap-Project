%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step8_build_GUI_LUT_allCenters_revised.m
% 说明：基于新的 CP_centers_all 文件命名方式（ICARE_ID_IDX.mat），
%      从 AllCenters/CP_centers_all 中提取：
%        - subjectID   (e.g. 'ICARE_0015')
%        - idx_center  (CP-window 索引)
%        - idx_range   (起止窗索引)
%        - prediction  (最高预测类别)
%        - probs       (所有类别概率向量)
%      保存到 GUI_results/AllCenters/GUI_LUT_allCenters.mat
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear;
% 关闭所有图窗（若存在）
try close all; catch; end

%% 0. 配置路径
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
baseDir  = fullfile(projRoot, 'GUI_results', 'AllCenters', 'CP_centers_all');
outFile  = fullfile(projRoot, 'GUI_results', 'AllCenters', 'GUI_LUT_allCenters.mat');

%% 1. 列出所有样本文件
files = dir(fullfile(baseDir, '*.mat'));
if isempty(files)
    error('未在 %s 找到任何样本文件', baseDir);
end

%% 2. 类别映射
pp = {'Seizure','LPD','GPD','LRDA','GRDA','Other'};

%% 3. 初始化 LUT_all （NumSamples × 5）
% 列依次为：{subjectID, idx_center, idx_range, prediction, probs}
LUT_all = cell(numel(files), 5);

%% 4. 主循环：从每个 .mat 文件中提取信息
for i = 1:numel(files)
    fn = files(i).name;                  % e.g. 'ICARE_0015_001.mat'
    nameNoExt = fn(1:end-4);            % 'ICARE_0015_001'
    parts = split(nameNoExt, '_');      % {'ICARE','0015','001'}
    subjectID  = strjoin(parts(1:2), '_');          % 'ICARE_0015'
    idx_center = str2double(parts{3});              % 1, 2, 3, ...
    
    % 加载 scores 和 idx_range
    S = load(fullfile(baseDir, fn), 'scores', 'idx_range');
    probs      = S.scores(:)';                     % 行向量，长度 = nClasses
    [~, mx]    = max(probs);
    prediction = pp{mx};                           % 预测标签
    idx_range  = S.idx_range;                      % [start end]
    
    % 填入 LUT_all
    LUT_all(i, :) = {
        subjectID, ...
        idx_center, ...
        idx_range, ...
        prediction, ...
        probs
    };
    
    fprintf('(%d/%d) %s → subjectID=%s, centerIdx=%d, pred=%s\n', ...
        i, numel(files), nameNoExt, subjectID, idx_center, prediction);
end

%% 5. 保存全局 LUT
save(outFile, 'LUT_all');
fprintf('✅ 已生成全局 GUI_LUT_allCenters → %s\n', outFile);