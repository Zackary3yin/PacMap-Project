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
try close all; catch; end

%% 0) 路径策略
projRoot = fileparts(mfilename('fullpath'));                          %%% 修改：以"当前脚本目录"为根
baseDir  = fullfile(projRoot, 'GUI_results', 'AllCenters', 'CP_centers_all');  %%% 修改
outFile  = fullfile(projRoot, 'GUI_results', 'AllCenters', 'GUI_LUT_allCenters.mat'); %%% 修改

%% 1) 列出所有样本文件
if ~exist(baseDir, 'dir')
    error('未找到目录：%s（请先完成 Step7 输出 CP_centers_all）', baseDir);
end
files = dir(fullfile(baseDir, '*.mat'));
if isempty(files)
    error('未在 %s 找到任何样本文件（请确认 Step7 是否已生成文件）', baseDir);
end

%% 2) 类别映射（按你的 6 类顺序）
pp = {'Seizure','LPD','GPD','LRDA','GRDA','Other'};

%% 3) 初始化 LUT_all （NumSamples × 5）
% 列依次为：{subjectID, idx_center, idx_range, prediction, probs}
LUT_all = cell(numel(files), 5);

%% 4) 主循环：从每个 .mat 文件中提取信息
cnt = 0;
for i = 1:numel(files)
    fn = files(i).name;                         % e.g. 'ICARE_0015_001.mat'
    nameNoExt = fn(1:end-4);                    % 'ICARE_0015_001'
    parts = split(nameNoExt, '_');              % {'ICARE','0015','001'}
    if numel(parts) < 3
        warning('文件名不符合 ICARE_ID_IDX 规范，已跳过：%s', fn);
        continue;
    end
    subjectID  = strjoin(parts(1:2), '_');      % 'ICARE_0015'
    idx_center = str2double(parts{3});          % 1, 2, 3, ...

    % 加载 scores 和 idx_range（Step7 的产物）
    S = load(fullfile(baseDir, fn));
    if ~isfield(S, 'scores')
        warning('缺少变量 scores，跳过：%s', fn);
        continue;
    end
    if ~isfield(S, 'idx_range')
        warning('缺少变量 idx_range，跳过：%s', fn);
        continue;
    end

    probs = S.scores(:)';                       % 行向量，长度 = nClasses
    if isempty(probs) || ~isnumeric(probs)
        warning('scores 非数值或为空，跳过：%s', fn);
        continue;
    end
    [~, mx] = max(probs);
    if mx < 1 || mx > numel(pp)
        predLabel = 'Unknown';
    else
        predLabel = pp{mx};
    end
    idx_range = S.idx_range;                    % [start end]

    cnt = cnt + 1;
    LUT_all(cnt, :) = {subjectID, idx_center, idx_range, predLabel, probs};

    fprintf('(%d/%d) %s → subjectID=%s, centerIdx=%d, pred=%s\n', ...
        i, numel(files), nameNoExt, subjectID, idx_center, predLabel);
end

% 去掉可能的空行（若有因跳过而未填充）
if cnt < size(LUT_all,1)
    LUT_all = LUT_all(1:cnt, :);
end

%% 5) 保存全局 LUT
if ~exist(fileparts(outFile), 'dir')
    mkdir(fileparts(outFile));
end
save(outFile, 'LUT_all');
fprintf('✅ 已生成全局 GUI_LUT_allCenters → %s（共 %d 条）\n', outFile, size(LUT_all,1));