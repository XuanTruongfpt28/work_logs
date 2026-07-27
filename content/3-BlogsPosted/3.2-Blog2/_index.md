---
title: "Blog 2"
date: 2026-06-06
weight: 2
chapter: false
pre: " <b> 3.2. </b> "
---
# Blog 2 – AWS Shield Advanced Attack Flow Logs for DDoS Monitoring

## Overview

During my internship, I researched and wrote a technical blog about **AWS Shield Advanced Attack Flow Logs**, a newly introduced feature that provides detailed visibility into Distributed Denial of Service (DDoS) attacks. The blog was based on the official AWS Security Blog and focused on how Attack Flow Logs help security teams analyze attack traffic more effectively instead of relying only on high-level metrics. :contentReference[oaicite:0]{index=0}

The objective of this blog was to improve my understanding of AWS Shield Advanced and learn how AWS supports organizations in monitoring, investigating, and responding to DDoS attacks.

## Research Process

To complete this blog, I performed the following activities:

- Read the official AWS Security Blog introducing Attack Flow Logs.
- Studied AWS Shield Advanced and its DDoS protection capabilities.
- Learned how Attack Flow Logs capture network traffic metadata during DDoS attacks.
- Explored the supported log destinations, including Amazon S3, Amazon CloudWatch Logs, and Amazon Data Firehose.
- Summarized the technical content from the perspective of a student learning AWS Security.

## Main Topics Covered

The blog covers several important topics, including:

- An overview of AWS Shield Advanced and its DDoS protection capabilities.
- The purpose and benefits of Attack Flow Logs.
- Traffic metadata captured during an attack, including:
  - Source and destination IP addresses.
  - Network protocols.
  - Packet and byte counts.
  - Source country information.
  - AWS Edge Location.
  - Shield mitigation actions.
- Exporting logs to Amazon S3, Amazon CloudWatch Logs, and Amazon Data Firehose.
- Integration with Amazon Athena, CloudWatch Logs Insights, and third-party SIEM platforms such as Splunk for further analysis.
- The importance of traffic visibility for post-incident investigation and security monitoring. :contentReference[oaicite:1]{index=1}

## Knowledge and Skills Gained

Through researching and writing this blog, I gained a better understanding of:

- AWS Shield Advanced and its role in protecting cloud applications from DDoS attacks.
- How Attack Flow Logs provide detailed visibility into attack traffic.
- The importance of monitoring and analyzing network traffic after security incidents.
- Reading and understanding AWS technical documentation.
- Summarizing complex technical concepts into clear and understandable content.

## Outcome

This activity strengthened my understanding of AWS Shield Advanced, DDoS mitigation, and cloud security monitoring. It also improved my technical research, documentation, and communication skills, which will be valuable for future AWS projects and security-related work.

## Image

![AWS Shield Advanced Attack Flow Logs](/images/blog2.jpg)
## Blog Link

- Facebook Post:
  https://www.facebook.com/groups/awsstudygroupfcj/posts/2175946893170271

## References

- AWS Security Blog:
  https://aws.amazon.com/blogs/security/gain-visibility-into-ddos-attacks-with-flow-logs-in-aws-shield-advanced/
