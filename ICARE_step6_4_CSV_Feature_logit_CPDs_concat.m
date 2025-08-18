%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_4_extract_cpd_features_multiCenter.m
% 多中心模式：从聚合特征中提取 CP center 对应的特征行
% 并保存为 Xagg_cpd、Xlogit_cpd 变量
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 1. 项目根目录 & 中心列表 ————
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
centers = {'UTW', 'MGH', 'BWH'};  % 自行修改添加中心名

% ———— 2. 遍历每个中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    % 设置路径
    featDir = fullfile(projRoot, 'GUI_results', center, 'model_prediction', 'model_prediction_fet_s');
    cpdDir  = fullfile(projRoot, 'GUI_results', center, 'CPDs1_s');

    featFiles = dir(fullfile(featDir, '*.mat'));
    if isempty(featFiles)
        warning('⚠️ 中心 %s 无特征文件，跳过\n', center);
        continue;
    end

    % 遍历每位被试文件
    for i = 1:numel(featFiles)
        fn = featFiles(i).name;
        base = fn(1:end-4);  % 被试 ID，如 ICARE_0012

        fprintf('(%d/%d) [%s] 处理 %s\n', i, numel(featFiles), center, fn);

        % 1. 读取 CPD 中 isCPcenters_s
        cpdPath = fullfile(cpdDir, [base '.mat']);
        if ~exist(cpdPath, 'file')
            warning('❌ 缺失 CPD 聚合文件，跳过: %s', cpdPath);
            continue;
        end
        C = load(cpdPath, 'isCPcenters_s');
        mask = logical(C.isCPcenters_s(:,2));

        % 2. 加载聚合特征与 logit 特征
        S = load(fullfile(featDir, fn), 'agg', 'csv_data_fe_s_logitz');
        Xagg = S.agg;
        Xlogit = S.csv_data_fe_s_logitz;

        % 3. 校正 mask 长度
        nAgg = size(Xagg, 1);
        nMask = numel(mask);
        if nMask > nAgg
            warning('⚠️ mask 长度 %d > 特征行数 %d，截断', nMask, nAgg);
            mask = mask(1:nAgg);
        elseif nMask < nAgg
            warning('⚠️ mask 长度 %d < 特征行数 %d，补齐', nMask, nAgg);
            mask = [mask; false(nAgg - nMask, 1)];
        end

        % 4. 提取变化点中心帧的特征子集
        Xagg_cpd = Xagg(mask, :);
        Xlogit_cpd = Xlogit(mask, :);

        % 5. 保存到原文件中
        save(fullfile(featDir, fn), 'Xagg_cpd', 'Xlogit_cpd', '-append');
    end

    fprintf('✅ 中心 %s 提取完成，共处理 %d 个被试文件\n', center, numel(featFiles));
end