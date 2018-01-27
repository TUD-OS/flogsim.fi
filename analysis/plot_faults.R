#!/usr/bin/env Rscript

suppressMessages(library(plyr))
suppressMessages(library(dplyr))
suppressMessages(library(stringr))
suppressMessages(library(ggplot2))
suppressMessages(library(optparse))

option.list <- list(
    make_option(c("-r", "--runtime"), default = "runtime.pdf", metavar = "FILE",
                help = "Output PDF file with runtime analysis. [default: %default]"),
    make_option(c("-m", "--messages"), default = "messages.pdf", metavar = "FILE",
                help = "Output PDF file with communication analysis. [default: %default]"))

opt.parser <- OptionParser(option_list = option.list,
                           usage = "%prog [options]")
opt <- parse_args(opt.parser, positional_arguments = 1)

log.dir <- opt$args

if (!dir.exists(log.dir)) {
    stop(paste("Directory", log.dir, "does not exist"))
}

plan <- read.csv(file.path(log.dir, 'experiment_plan.csv'))
runs <- read.csv(file.path(log.dir, 'experiment_logs.csv'))

runtime.file <- opt$options$runtime
pdf(runtime.file, width = 7, height = 4)

res <- plan %>%
    inner_join(runs)

## This is a hack to fix the fact that for gossip TotalRuntime appears
## in RootTreeEnd column
res <- res %>%
    mutate(TotalRuntime = ifelse(COLL == 'checked_corrected_gossip_bcast', RootTreeEnd,
                                 TotalRuntime)) %>%
    mutate(RootTreeEnd = ifelse(COLL == 'checked_corrected_gossip_bcast', NA,
                                RootTreeEnd))

res <- res %>%
    group_by(COLL, k, PAR, L, o, g, P, F) %>%
    filter(UnreachedNodes == 0) %>%
    summarise(avg_runtime = mean(TotalRuntime),
              avg_msg = mean(MsgTask),
              sd_runtime = sd(TotalRuntime),
              sd_msg = sd(MsgTask)) %>%
    ungroup() %>%
    collect()

get.mode <- function(phased, always) {
    if (phased)
        return('phased')
    if (always)
        return('always')
    return('normal')
}

res <- res %>%
    mutate(phased = grepl('phased', COLL),
           always = grepl('always', COLL)) %>%
    mutate(COLL = str_replace_all(COLL, '(phased_|always_)', '')) %>%
    rowwise() %>%
    mutate(mode = get.mode(phased, always)) %>%
    collect()

max.runtime = max(res$avg_runtime + res$sd_runtime + 0.1)

node.list <- unique(res$P)

res <- mutate(res, COLL = revalue(COLL,
                                  c("checked_corrected_binomial_bcast" = "Checked binomial",
                                    "checked_corrected_optimal_bcast" = "Checked optimal",
                                    "checked_corrected_lame_bcast" = "Checked Lame",
                                    "checked_corrected_kary_bcast" = "Checked k-ary",
                                    "checked_corrected_gossip_bcast" = "Checked gossip"
                                    )))

res <- mutate(res, k = as.factor(k))

p <- res %>%
    group_by(PAR, L, o, g, F, COLL) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_runtime,
                          lty = mode, col = k)) +
            ylim(0, max.runtime) +
            ggtitle("Scalability at the same fault rate",
                    subtitle = paste("F =", .$F, "%", "L =", .$L, "o = ", .$o, "g =", .$g, "PAR =", .$PAR, "COLL =", .$COLL)) +
            ylab("Runtime, steps") +
            guides(lty = guide_legend(title = "Collective")) +
            theme_linedraw(base_size = 10) +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )
print(p$plots)

p <- res %>%
    group_by(PAR, L, o, g, F) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_runtime,
                          lty = COLL, col = k)) +
            ylim(0, max.runtime) +
            ggtitle("Scalability at the same fault rate",
                    subtitle = paste("F =", .$F, "%", "L =", .$L, "o = ", .$o, "g =", .$g, "PAR =", .$PAR)) +
            ylab("Runtime, steps") +
            guides(lty = guide_legend(title = "Collective")) +
            theme_linedraw(base_size = 10) +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )

add.log.scale <- function(p) p + scale_x_log10(breaks = node.list, labels = node.list)

print(p$plots)
print(lapply(p$plots, function(p) p +
                                  scale_x_continuous() +
                                  geom_errorbar(aes(x = P,
                                                    ymin = avg_runtime - sd_runtime,
                                                    ymax = avg_runtime + sd_runtime,
                                                    lty = COLL, group = k), alpha=0.5)))
print(lapply(p$plots, add.log.scale))

p <- res %>%
    filter(F %in% c(1, 2, 4, 6, 8, 10)) %>%
    collect() %>%
    group_by(L, o, g, k, PAR, COLL) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_runtime, color = as.factor(F))) +
            ylim(0, max.runtime) +
            ggtitle("Sturdiness with growing number of faults",
                    subtitle = paste(.$COLL, "L =", .$L, "o = ", .$o, "g =", .$g, "k =", .$k, "PAR =", .$PAR)) +
            ylab("Runtime, steps") +
            guides(color = guide_legend(title = "F (%)")) +
            scale_color_brewer(type = "seq", palette="Oranges") +
            theme_linedraw() +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )

print(p$plots)
print(lapply(p$plots, add.log.scale))

dev.off()

pdf(opt$options$messages, width = 7, height = 4)

max.msg = max(res$avg_msg + res$sd_msg + 0.1)

p <- res %>%
    group_by(PAR, L, o, g, F) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_msg, linetype = COLL, col = k)) +
            ylim(0, max.msg) +
            ggtitle("Scalability at the same fault rate",
                    subtitle = paste("F =", .$F, "%", "L =", .$L, "o = ", .$o, "g =", .$g, "PAR =", .$PAR)) +
            ylab("Messages, count") +
            guides(lty = guide_legend(title = "Collective")) +
            theme_linedraw(base_size = 10) +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )

print(p$plots)
print(lapply(p$plots, function(p) p +
                                  scale_x_continuous() +
                                  geom_errorbar(aes(x = P,
                                                    ymin = avg_msg - sd_msg,
                                                    ymax = avg_msg + sd_msg,
                                                    lty = COLL,
                                                    col = k), alpha=0.5)))
print(lapply(p$plots, add.log.scale))

p <- res %>%
    filter(F %in% c(1, 2, 4, 6, 8, 10)) %>%
    collect() %>%
    group_by(L, o, g, k, PAR, COLL) %>%
    do (
        plots = ggplot(data = .) +
            geom_line(aes(x = P, y = avg_msg, color = as.factor(F))) +
            ylim(0, max.msg) +
            ggtitle("Sturdiness with growing number of faults",
                    subtitle = paste(.$COLL, "L =", .$L, "o = ", .$o, "g =", .$g, "k =", .$k, "PAR =", .$PAR)) +
            ylab("Messages, count") +
            guides(color = guide_legend(title = "F (%)")) +
            scale_color_brewer(type = "seq", palette="Oranges") +
            theme_linedraw() +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(colour='gray'),
                  legend.box.background = element_rect())
    )
print(p$plots)
print(lapply(p$plots, add.log.scale))

dev.off()
