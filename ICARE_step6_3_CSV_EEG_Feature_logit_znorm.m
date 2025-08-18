%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_3_transform_and_save_features_multiCenter.m
% 多中心模式：对各中心的聚合特征矩阵执行 logit(rescale) + Z-score
% 写回每位被试的文件（csv_data_fe_s_logitz）
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 1. 根目录 & 中心列表 ————
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
centers = {'UTW', 'MGH', 'BWH'};  % 根据需要调整

% ———— 2. 遍历每个中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    dataDir = fullfile(projRoot, 'GUI_results', center, 'model_prediction', 'model_prediction_fet_s');
    if ~exist(dataDir, 'dir')
        warning('⚠️ 目录不存在: %s，跳过', dataDir);
        continue;
    end

    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        warning('⚠️ 中心 %s 无 .mat 特征文件，跳过', center);
        continue;
    end

    % ———— 3. 聚合所有数据以便全局标准化 ————
    allData = [];
    meta = struct('fileName',{}, 'startIdx',{}, 'endIdx',{});
    cumRows = 0;

    for i = 1:numel(files)
        fn = files(i).name;
        S = load(fullfile(dataDir, fn), 'agg');
        X = S.agg;

        % 预处理：绝对值 & 清除异常
        X(abs(X)==Inf | isnan(X)) = 0;
        X = abs(X);

        % logit(rescale)
        [nR, nC] = size(X);
        Xp = zeros(nR, nC);
        for r = 1:nR
            v = X(r, :);
            vp = rescale(v, 0, 1);
            vp = min(max(vp, eps), 1 - eps);  % 限制在 (eps, 1-eps)
            Xp(r, :) = log(vp ./ (1 - vp));
        end

        % 累计合并
        startIdx = cumRows + 1;
        endIdx = cumRows + nR;
        cumRows = endIdx;

        allData(startIdx:endIdx, :) = Xp;

        meta(i).fileName = fn;
        meta(i).startIdx = startIdx;
        meta(i).endIdx   = endIdx;
    end

    % ———— 4. 全局 Z-score 标准化（按列） ————
    allData = normalize(allData, 1);

    % ———— 5. 写回各被试文件 ————
    for i = 1:numel(meta)
        fn = meta(i).fileName;
        Zdata = allData(meta(i).startIdx : meta(i).endIdx, :);
        csv_data_fe_s_logitz = Zdata; %#ok<NASGU>
        save(fullfile(dataDir, fn), 'csv_data_fe_s_logitz', '-append');
        fprintf('✅ (%d/%d) 写入标准化特征: [%s] %s\n', i, numel(meta), center, fn);
    end

    fprintf('✅ 中心 %s 特征标准化完成，共 %d 个文件\n', center, numel(files));
end