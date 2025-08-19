%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_4_extract_cpd_features_multiCenter.m
% 多中心模式：从聚合特征中提取 CP center 对应的特征行
% 并保存为 Xagg_cpd、Xlogit_cpd 变量
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 0) 路径策略（当前脚本目录为根） ————
projRoot = fileparts(mfilename('fullpath'));                     %%% 修改：以脚本目录为根

% ———— 1) 中心列表 ————
centers  = {'BIDMC','MGH','ULB'};                                %%% 修改：按你的数据更新

% ———— 2) 遍历每个中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    % 设置路径（均在脚本目录 GUI_results 下）
    featDir = fullfile(projRoot, 'GUI_results', center, ...
                       'model_prediction', 'model_prediction_fet_s');        %%% 修改
    cpdDir  = fullfile(projRoot, 'GUI_results', center, 'CPDs1_s');          %%% 修改

    if ~exist(featDir, 'dir')
        warning('⚠️ 中心 %s 无特征目录：%s，跳过', center, featDir);
        continue;
    end
    if ~exist(cpdDir, 'dir')
        warning('⚠️ 中心 %s 无 CPD 聚合目录：%s，跳过', center, cpdDir);
        continue;
    end

    featFiles = dir(fullfile(featDir, '*.mat'));
    if isempty(featFiles)
        warning('⚠️ 中心 %s 无特征文件，跳过\n', center);
        continue;
    end

    % 遍历每位被试文件
    for i = 1:numel(featFiles)
        fn   = featFiles(i).name;
        base = fn(1:end-4);  % 被试 ID，如 ICARE_0012

        fprintf('(%d/%d) [%s] 处理 %s\n', i, numel(featFiles), center, fn);

        % 1) 读取 CPD 的 isCPcenters_s（第二列为布尔标签；第一列为段索引）
        cpdPath = fullfile(cpdDir, [base '.mat']);
        if ~exist(cpdPath, 'file')
            warning('❌ 缺失 CPD 聚合文件，跳过: %s', cpdPath);
            continue;
        end
        C = load(cpdPath);
        if ~isfield(C, 'isCPcenters_s')
            warning('❌ %s 中缺少 isCPcenters_s，跳过', cpdPath);
            continue;
        end
        if size(C.isCPcenters_s,2) < 2
            warning('❌ %s 中 isCPcenters_s 列数不足，跳过', cpdPath);
            continue;
        end
        mask = logical(C.isCPcenters_s(:,2));

        % 2) 加载聚合特征与 logit 特征
        S = load(fullfile(featDir, fn));
        if ~isfield(S, 'agg')
            warning('❌ %s 缺少 agg，跳过', fn);
            continue;
        end
        if ~isfield(S, 'csv_data_fe_s_logitz')
            warning('❌ %s 缺少 csv_data_fe_s_logitz，跳过', fn);
            continue;
        end
        Xagg   = S.agg;
        Xlogit = S.csv_data_fe_s_logitz;

        % 3) 校正 mask 长度
        nAgg  = size(Xagg, 1);
        nLog  = size(Xlogit, 1);
        if nLog ~= nAgg
            warning('⚠️ %s: agg(%d) ≠ logit(%d)，按较小值对齐', fn, nAgg, nLog);
            nAgg = min(nAgg, nLog);
            Xagg   = Xagg(1:nAgg, :);
            Xlogit = Xlogit(1:nAgg, :);
        end
        nMask = numel(mask);
        if nMask > nAgg
            warning('⚠️ mask 长度 %d > 特征行数 %d，截断', nMask, nAgg);
            mask = mask(1:nAgg);
        elseif nMask < nAgg
            warning('⚠️ mask 长度 %d < 特征行数 %d，补齐为 false', nMask, nAgg);
            mask = [mask; false(nAgg - nMask, 1)];
        end

        % 4) 提取变化点中心帧的特征子集
        Xagg_cpd   = Xagg(mask, :);
        Xlogit_cpd = Xlogit(mask, :);

        % 5) 保存到原文件（追加）
        save(fullfile(featDir, fn), 'Xagg_cpd', 'Xlogit_cpd', '-append');
    end

    fprintf('✅ 中心 %s 提取完成，共处理 %d 个被试文件\n', center, numel(featFiles));
end