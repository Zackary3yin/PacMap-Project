%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_3_transform_and_save_features_multiCenter.m
% 多中心模式：对各中心的聚合特征矩阵执行 logit(rescale) + Z-score
% 写回每位被试的文件（csv_data_fe_s_logitz）
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 0) 路径策略（当前脚本目录为根） ————
projRoot = fileparts(mfilename('fullpath'));                      %%% 修改：输出/输入均以脚本目录为根

% ———— 1) 中心列表 ————
centers  = {'BIDMC','MGH','ULB'};                                 %%% 修改：按你的数据更新

% ———— 2) 遍历每个中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    dataDir = fullfile(projRoot, 'GUI_results', center, ...
                       'model_prediction', 'model_prediction_fet_s');    %%% 修改：从脚本目录读取被试聚合特征
    if ~exist(dataDir, 'dir')
        warning('⚠️ 目录不存在: %s，跳过', dataDir);
        continue;
    end

    files = dir(fullfile(dataDir, '*.mat'));
    if isempty(files)
        warning('⚠️ 中心 %s 无 .mat 特征文件，跳过', center);
        continue;
    end

    % ———— 3) 聚合所有数据以便"全局标准化" ————
    allData = [];
    meta = struct('fileName',{}, 'startIdx',{}, 'endIdx',{});
    cumRows = 0;

    for i = 1:numel(files)
        fn = files(i).name;
        S = load(fullfile(dataDir, fn), 'agg');
        if ~isfield(S,'agg')
            warning('❌ 缺少变量 agg：%s（跳过）', fn);
            continue;
        end
        X = S.agg;

        % 预处理：把 NaN/Inf 置零，再取绝对值（保持你的习惯）
        X(~isfinite(X)) = 0;
        X = abs(X);

        % ---------- logit(rescale) ----------
        % 行内 rescale 到 (0,1) 后做 logit；对常量行做微扰，避免除零或 NaN
        [nR, nC] = size(X);
        Xp = zeros(nR, nC);

        %%% 修改：对常量行做微小扰动，避免 rescale 时 0/0
        rowMin = min(X, [], 2);
        rowMax = max(X, [], 2);
        isConstRow = (rowMax - rowMin) == 0;
        if any(isConstRow)
            % 在常量行上加极小噪声（不影响统计，但能避免数值问题）
            epsJitter = 1e-12;
            X(isConstRow, :) = X(isConstRow, :) + epsJitter*randn(sum(isConstRow), nC);
            rowMin(isConstRow) = min(X(isConstRow,:), [], 2);
            rowMax(isConstRow) = max(X(isConstRow,:), [], 2);
        end

        % 行级 rescale： (X - min) / (max - min)
        denom = (rowMax - rowMin);
        denom(denom==0) = 1;  % 保护
        Xrs = (X - rowMin) ./ denom;

        % 限制到 (eps, 1-eps) 避免 logit 溢出
        epsv = eps;  % MATLAB 机器精度
        Xrs = min(max(Xrs, epsv), 1 - epsv);

        % logit
        Xp = log(Xrs ./ (1 - Xrs));

        % 累计合并
        startIdx = cumRows + 1;
        endIdx   = cumRows + nR;
        cumRows  = endIdx;

        allData(startIdx:endIdx, :) = Xp;

        meta(end+1).fileName = fn;       %#ok<SAGROW>
        meta(end).startIdx    = startIdx;
        meta(end).endIdx      = endIdx;
    end

    if isempty(allData)
        warning('⚠️ 中心 %s 无可用数据进入标准化流程，跳过', center);
        continue;
    end

    % ———— 4) 全局 Z-score 标准化（按列） ————
    %%% 修改：使用 zscore，并对 sigma==0 的列做保护，避免 NaN
    [Z, mu, sigma] = zscore(allData);      % 列方向
    sigma_safe = sigma;
    sigma_safe(sigma_safe==0) = 1;         % 避免除以 0
    allDataZ = (allData - mu) ./ sigma_safe;

    % ———— 5) 写回各被试文件（追加变量 csv_data_fe_s_logitz） ————
    for i = 1:numel(meta)
        fn = meta(i).fileName;
        Zdata = allDataZ(meta(i).startIdx : meta(i).endIdx, :);
        csv_data_fe_s_logitz = Zdata; %#ok<NASGU>
        save(fullfile(dataDir, fn), 'csv_data_fe_s_logitz', '-append');
        fprintf('✅ (%d/%d) 写入标准化特征: [%s] %s\n', i, numel(meta), center, fn);
    end

    fprintf('✅ 中心 %s 特征标准化完成，共 %d 个文件\n', center, numel(files));
end