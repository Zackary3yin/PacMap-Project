%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_2_aggregate_cpd_by_subject_multiCenter.m
% 多中心模式：按被试 ID 聚合 CPDs1 中的变化点检测结果
% 输出 lut_cpd_s、isCPcenters_s、isCPs_s 到 CPDs1_s/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 0) 路径策略 ————
projRoot = fileparts(mfilename('fullpath'));      %%% 修改：以"当前脚本目录"为根（读/写均在此）

% ———— 1) 定义中心列表 ————
centers  = {'BIDMC','MGH','ULB'};                 %%% 修改：按你的实际中心更新

% ———— 2) 遍历所有中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    % 设置输入输出路径（均在脚本目录 GUI_results 下）
    cpdDir = fullfile(projRoot, 'GUI_results', center, 'CPDs1');     %%% 修改
    outDir = fullfile(projRoot, 'GUI_results', center, 'CPDs1_s');   %%% 修改
    if ~exist(cpdDir, 'dir')
        warning('⚠️ 未找到目录: %s，跳过该中心', cpdDir);
        continue;
    end
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    % 获取所有 _cpc.mat 文件
    files = dir(fullfile(cpdDir, '*_cpc.mat'));
    if isempty(files)
        fprintf('⚠️ 中心 %s 中无 CPD 文件，跳过\n', center);
        continue;
    end
    fileNames = {files.name}';

    % 提取被试 ID，例如 ICARE_0012
    tmpParts = split(fileNames, '_');
    subjectIDs = strcat(tmpParts(:,1), '_', tmpParts(:,2));
    uniqueIDs = unique(subjectIDs);

    % 聚合每个被试
    for i = 1:numel(uniqueIDs)
        sid = uniqueIDs{i};
        idx = find(strcmp(subjectIDs, sid));

        lut_cpd_s = [];
        isCPcenters_s = [];
        isCPs_s = [];

        for j = 1:numel(idx)
            % 加载第 j 个 segment 的 CPD 文件
            S = load(fullfile(cpdDir, fileNames{idx(j)}));

            % 健壮性检查（可防止少字段时崩溃）
            if ~isfield(S, 'lut_cpd') || ~isfield(S, 'isCPcenters') || ~isfield(S, 'isCPs')
                warning('⚠️ 缺少必要变量(lut_cpd/isCPcenters/isCPs)：%s（已跳过）', fileNames{idx(j)});
                continue;
            end

            % 1) 合并 lut_cpd（带 segment ID）
            segIdx_lut = j * ones(size(S.lut_cpd,1), 1);
            lut_cpd_s  = [lut_cpd_s; segIdx_lut, S.lut_cpd];

            % 2) 合并 isCPcenters（每窗口一个标签）
            nWin = numel(S.isCPcenters);
            segIdx_win = j * ones(nWin, 1);
            isCPcenters_s = [isCPcenters_s; segIdx_win, S.isCPcenters(:)];

            % 3) 合并 isCPs
            isCPs_s = [isCPs_s; segIdx_win, S.isCPs(:)];
        end

        if isempty(lut_cpd_s) && isempty(isCPcenters_s) && isempty(isCPs_s)
            warning('⚠️ 被试 %s 在中心 %s 无可聚合数据，跳过保存', sid, center);
            continue;
        end

        % 保存合并结果（到脚本目录）
        save(fullfile(outDir, [sid '.mat']), 'lut_cpd_s', 'isCPcenters_s', 'isCPs_s', '-v7.3');
        fprintf('✅ (%d/%d) [%s] 完成聚合: %s\n', i, numel(uniqueIDs), center, sid);
    end

    fprintf('✅ 中心 %s 聚合完成，共 %d 名被试\n', center, numel(uniqueIDs));
end